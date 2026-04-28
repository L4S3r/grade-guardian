import hmac
import hashlib
import secrets
import os
from typing import List, Optional
from datetime import datetime,timezone
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, String, Float, DateTime, Boolean, ForeignKey  
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel, ConfigDict, Field

# --- 1. SECURITY & SALT SETUP ---
SALT_FILE = "secret_salt.txt"

def get_or_create_salt():
    if os.path.exists(SALT_FILE):
        with open(SALT_FILE, "r") as f:
            return f.read().strip()
    else:
        new_salt = secrets.token_hex(32)
        with open(SALT_FILE, "w") as f:
            f.write(new_salt)
        return new_salt

SECRET_SALT = os.getenv("SECRET_SALT", get_or_create_salt())

def build_grade_data_string(grade_id, student_id, course_code, grade, recorded_at):
    ts_str = recorded_at.replace("Z", "").split(".")[0]
    grade_val = "{:.1f}".format(float(grade))  # ← add this
    return f"{grade_id}|{student_id}|{course_code}|{grade_val}|{ts_str}"

def compute_hash(data_string: str):
    return hmac.new(
        SECRET_SALT.encode(),
        data_string.encode(),
        hashlib.sha256
    ).hexdigest()

# --- 2. DATABASE SETUP ---
DATABASE_URL = os.getenv("DATABASE_URL")
if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

if not DATABASE_URL:
    DATABASE_URL = "sqlite:///./grades.db"

DATABASE_URL = "sqlite:///./grades.db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class GradeDB(Base):
    __tablename__ = "grades"
    id = Column(String, primary_key=True, index=True)
    student_id = Column(String, index=True)
    course_name = Column(String)
    course_code = Column(String)
    grade = Column(Float)
    letter_grade = Column(String)
    recorded_at = Column(DateTime, default=datetime.utcnow)
    hash = Column(String)

class AuditLogDB(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    grade_id = Column(String, ForeignKey("grades.id"), index=True)
    action = Column(String)  
    status = Column(String)  
    checked_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    # MUST be error_details to match your get_grades logic
    error_details = Column(String, nullable=True)
    
Base.metadata.create_all(bind=engine)

# --- 3. SCHEMAS (PYDANTIC) ---
class GradeCreate(BaseModel):
    student_id: str
    course_name: str
    course_code: str
    grade: float
    letter_grade: str

class GradeResponse(GradeCreate):
    id: str
    student_id: str
    course_name: str
    course_code: str
    grade: float
    letter_grade: str
    recorded_at: datetime
    hash: str
    is_verified: bool = Field(default=True)
    
    model_config = ConfigDict(from_attributes=True)

class AuditLogResponse(BaseModel):
    grade_id: str
    status: str
    checked_at: datetime
    error_details: Optional[str]

# --- 4. API CONFIG & DEPENDENCIES ---
app = FastAPI(title="GradeGuardian API", description="API for managing and verifying student grade records with HMAC integrity checks.", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- 5. ENDPOINTS ---

@app.get("/grades", response_model=List[GradeResponse])
async def get_grades(student_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(GradeDB)
    if student_id:
        query = query.filter(GradeDB.student_id == student_id)
    
    grades = query.all()
    results = []
    
    for g in grades:
        # DYNAMIC VERIFICATION: Check the hash on every fetch
        data_to_hash = build_grade_data_string(
    g.id,
    g.student_id,
    g.course_code,
    g.grade,
    g.recorded_at.isoformat()
)
        current_hash = compute_hash(data_to_hash)
        is_verified = (current_hash == g.hash)
        
        # Log the check result
        db.add(AuditLogDB(
            grade_id=g.id,
            action="Automatic Integrity Check", # Added this missing field
            status="PASS" if is_verified else "FAIL",
            error_details=None if is_verified else "Hash mismatch"
            ))
        
        results.append({
            "id": g.id,
            "student_id": g.student_id,
            "course_name": g.course_name,
            "course_code": g.course_code,
            "grade": g.grade,
            "letter_grade": g.letter_grade,
            "recorded_at": g.recorded_at.isoformat(),
            "hash": g.hash,
            "is_verified": is_verified
        })
    
    db.commit()
    return results

@app.post("/grades", response_model=GradeResponse)
async def create_grade(grade_data: GradeCreate, db: Session = Depends(get_db)):
    import uuid
    
    # 1. Prepare the core data
    new_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    
    # 2. Create the Database Instance (without the hash yet)
    db_grade = GradeDB(
        id=new_id,
        student_id=grade_data.student_id,
        course_name=grade_data.course_name,
        course_code=grade_data.course_code,
        grade=grade_data.grade,
        letter_grade=grade_data.letter_grade,
        recorded_at=now
    )

    # 3. Generate the "Standard String" for hashing
    # This must match your build_grade_string function exactly!
    data_to_hash = build_grade_data_string(
    new_id,
    grade_data.student_id,
    grade_data.course_code,
    grade_data.grade,
    now.isoformat()
)
    
    # 4. Create the HMAC Seal
    db_grade.hash = hmac.new(
        SECRET_SALT.encode(),
        data_to_hash.encode(),
        hashlib.sha256
    ).hexdigest()
    
    # 5. Final Save to Alexandria's DB
    db.add(db_grade)
    db.commit()
    db.refresh(db_grade)
    
    return db_grade

@app.post("/repair/{grade_id}")
async def repair_grade(grade_id: str, db: Session = Depends(get_db)):
    grade = db.query(GradeDB).filter(GradeDB.id == grade_id).first()
    if not grade:
        raise HTTPException(status_code=404, detail="Grade not found")
    
    # Re-calculate hash with the current data and current salt
    data_string = build_grade_data_string(
        grade.id, grade.student_id, grade.course_code, grade.grade, grade.recorded_at.isoformat()
    )
    grade.hash = compute_hash(data_string)
    
    db.add(AuditLogDB(grade_id=grade.id, action="Admin Repair", status="REPAIRED", error_details="Admin manual re-seal"))
    db.commit()
    return {"status": "success", "message": "Integrity restored"}

@app.get("/audit-logs", response_model=List[AuditLogResponse])
async def get_audit_logs(db: Session = Depends(get_db)):
    return db.query(AuditLogDB).order_by(AuditLogDB.checked_at.desc()).limit(50).all()


@app.get("/grades/{grade_id}/logs")
def get_grade_logs(grade_id: str, db: Session = Depends(get_db)):
    logs = db.query(AuditLogDB).filter(AuditLogDB.grade_id == grade_id).all()
    return {"logs": logs}

@app.post("/verify/batch")
async def verify_batch(data: dict, db: Session = Depends(get_db)):
    grade_ids = data.get("grade_ids", [])

    results = []
    for g_id in grade_ids:
        grade = db.query(GradeDB).filter(GradeDB.id == g_id).first()
        if not grade:
            results.append({"grade_id": g_id, "is_valid": False, "error": "Not found"})
            continue

        # 1. Use the EXACT same string builder as create_grade
        data_string = build_grade_data_string(
            grade.id,
            grade.student_id,
            grade.course_code,
            grade.grade,
            grade.recorded_at.isoformat()
        )
        # 2. Use the EXACT same HMAC logic
        current_hash = hmac.new(
            SECRET_SALT.encode(),
            data_string.encode(),
            hashlib.sha256
        ).hexdigest()

        is_valid = (current_hash == grade.hash)

        # 3. Log the check with the missing 'action' field
        db.add(AuditLogDB(
            grade_id=grade.id,
            action="Batch Verification",
            status="PASS" if is_valid else "FAIL",
            error_details=None if is_valid else "Integrity mismatch detected on refresh"
        ))
        
        results.append({
            "grade_id": grade.id,
            "is_valid": is_valid,
            "error": None if is_valid else "Integrity check failed"
        })

    db.commit()
    return results

@app.get("/")
async def root():
    return {"message": "GradeGuardian API is Online", "status": "Secure"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
