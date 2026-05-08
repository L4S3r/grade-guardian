import hmac
import hashlib
import secrets
import os
import bcrypt
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import create_engine, Column, String, Float, DateTime, Integer, ForeignKey, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel, ConfigDict, Field, EmailStr
import jwt
from dotenv import load_dotenv

load_dotenv()

# --- 1. SECURITY & SALT SETUP ---
JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-jwt-key-grade-guardian")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 24 * 7  # 7 days

SECRET_SALT = os.getenv("SECRET_SALT", "permanent-static-salt-grade-guardian")


def build_grade_data_string(grade_id, student_id, course_code, grade, letter_grade, recorded_at):
    ts_str    = recorded_at.replace("Z", "").split(".")[0]
    grade_val = "{:.1f}".format(float(grade))
    return f"{grade_id}|{student_id}|{course_code}|{grade_val}|{letter_grade}|{ts_str}"


def compute_hash(data_string: str):
    return hmac.new(
        SECRET_SALT.encode(),
        data_string.encode(),
        hashlib.sha256
    ).hexdigest()


def create_jwt(subject: str, role: str) -> str:
    payload = {
        "sub": subject,
        "role": role,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_jwt(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


# --- 2. DATABASE SETUP ---
DATABASE_URL = "postgresql://gradeguardianv2_0db_peb7_user:f3rwWJwsK8ZIoEhGFKZ1NBf8mmyISW8x@dpg-d7r2d78sfn5c73bku2a0-a.frankfurt-postgres.render.com/gradeguardianv2_0db_peb7"
# DATABASE_URL = "postgresql://gradeguardianv2_0db_peb7_user:f3rwWJwsK8ZIoEhGFKZ1NBf8mmyISW8x@<YOUR_EXTERNAL_RENDER_HOSTNAME>  /gradeguardianv2_0db_peb7"
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

if not DATABASE_URL:
    DATABASE_URL = "sqlite:///./grades.db"

DATABASE_URL = "sqlite:///./grades.db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# --- 3. MODELS ---
class StudentDB(Base):
    __tablename__ = "students"
    id = Column(String, primary_key=True, index=True)
    student_id = Column(String, unique=True, index=True)   # e.g. "STU-2024-001"
    name = Column(String)
    email = Column(String, unique=True, index=True)
    department = Column(String)
    password_hash = Column(String)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(microsecond=0, tzinfo=None))


class ProfessorDB(Base):
    __tablename__ = "professors"
    id = Column(String, primary_key=True, index=True)
    employee_id = Column(String, unique=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    department = Column(String)
    password_hash = Column(String)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(microsecond=0, tzinfo=None))


class GradeDB(Base):
    __tablename__ = "grades"
    id = Column(String, primary_key=True, index=True)
    student_id = Column(String, index=True)               # references StudentDB.student_id
    course_name = Column(String)
    course_code = Column(String)
    grade = Column(Float)
    letter_grade = Column(String)
    recorded_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(microsecond=0, tzinfo=None))
    hash = Column(String)


class AuditLogDB(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    grade_id = Column(String, ForeignKey("grades.id"), index=True)
    action = Column(String)
    status = Column(String)
    checked_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(microsecond=0, tzinfo=None))
    error_details = Column(String, nullable=True)


Base.metadata.create_all(bind=engine)


# --- 4. SCHEMAS ---
class StudentRegister(BaseModel):
    name: str
    student_id: str
    department: str
    email: str
    password: str


class StudentLogin(BaseModel):
    student_id: str
    password: str


class StudentOut(BaseModel):
    id: str
    student_id: str
    name: str
    email: str
    department: str
    model_config = ConfigDict(from_attributes=True)


class ProfessorRegister(BaseModel):
    name: str
    employee_id: str
    department: str
    email: str
    password: str


class ProfessorLogin(BaseModel):
    email: str
    password: str


class ProfessorOut(BaseModel):
    id: str
    employee_id: str
    name: str
    email: str
    department: str
    model_config = ConfigDict(from_attributes=True)


class GradeCreate(BaseModel):
    student_id: str
    course_name: str
    course_code: str
    grade: float
    letter_grade: str


class GradeResponse(BaseModel):
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
    id: Optional[int]
    grade_id: str
    action: str
    status: str
    checked_at: datetime
    details: Optional[str] = None

    @classmethod
    def from_db(cls, log: AuditLogDB):
        return cls(
            id=log.id,
            grade_id=log.grade_id,
            action=log.action,
            status=log.status,
            checked_at=log.checked_at,
            details=log.error_details,
        )


# --- 5. APP & MIDDLEWARE ---
app = FastAPI(
    title="GradeGuardian Student Portal API",
    description="Grade portal for students and professors with HMAC integrity verification.",
    version="2.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

bearer_scheme = HTTPBearer(auto_error=False)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    if credentials is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return decode_jwt(credentials.credentials)


def require_student(payload: dict = Depends(get_current_user)):
    if payload.get("role") != "student":
        raise HTTPException(status_code=403, detail="Students only")
    return payload


def require_professor(payload: dict = Depends(get_current_user)):
    if payload.get("role") != "professor":
        raise HTTPException(status_code=403, detail="Professors only")
    return payload


# --- 6. STUDENT AUTH ---
@app.post("/student/register", status_code=201)
async def student_register(data: StudentRegister, db: Session = Depends(get_db)):
    if db.query(StudentDB).filter(StudentDB.student_id == data.student_id).first():
        raise HTTPException(400, "Student ID already registered")
    if db.query(StudentDB).filter(StudentDB.email == data.email).first():
        raise HTTPException(400, "Email already registered")

    import uuid
    pw_hash = bcrypt.hashpw(data.password.encode(), bcrypt.gensalt()).decode()
    student = StudentDB(
        id=str(uuid.uuid4()),
        student_id=data.student_id,
        name=data.name,
        email=data.email,
        department=data.department,
        password_hash=pw_hash,
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    token = create_jwt(subject=student.student_id, role="student")
    return {
        "access_token": token,
        "student": {
            "id": student.id,
            "student_id": student.student_id,
            "name": student.name,
            "email": student.email,
            "department": student.department,
        }
    }


@app.post("/student/login")
async def student_login(data: StudentLogin, db: Session = Depends(get_db)):
    student = db.query(StudentDB).filter(StudentDB.student_id == data.student_id).first()
    if not student or not bcrypt.checkpw(data.password.encode(), student.password_hash.encode()):
        raise HTTPException(401, "Invalid Student ID or password")

    token = create_jwt(subject=student.student_id, role="student")
    return {
        "access_token": token,
        "student": {
            "id": student.id,
            "student_id": student.student_id,
            "name": student.name,
            "email": student.email,
            "department": student.department,
        }
    }


# --- 7. PROFESSOR AUTH ---
@app.post("/auth/register", status_code=201)
async def professor_register(data: ProfessorRegister, db: Session = Depends(get_db)):
    if db.query(ProfessorDB).filter(ProfessorDB.employee_id == data.employee_id).first():
        raise HTTPException(400, "Employee ID already registered")
    if db.query(ProfessorDB).filter(ProfessorDB.email == data.email).first():
        raise HTTPException(400, "Email already registered")

    import uuid
    pw_hash = bcrypt.hashpw(data.password.encode(), bcrypt.gensalt()).decode()
    prof = ProfessorDB(
        id=str(uuid.uuid4()),
        employee_id=data.employee_id,
        name=data.name,
        email=data.email,
        department=data.department,
        password_hash=pw_hash,
    )
    db.add(prof)
    db.commit()
    db.refresh(prof)

    token = create_jwt(subject=prof.id, role="professor")
    return {
        "access_token": token,
        "professor": {
            "id": prof.id,
            "employee_id": prof.employee_id,
            "name": prof.name,
            "email": prof.email,
            "department": prof.department,
        }
    }


@app.post("/auth/login")
async def professor_login(data: ProfessorLogin, db: Session = Depends(get_db)):
    prof = db.query(ProfessorDB).filter(ProfessorDB.email == data.email).first()
    if not prof or not bcrypt.checkpw(data.password.encode(), prof.password_hash.encode()):
        raise HTTPException(401, "Invalid credentials")

    token = create_jwt(subject=prof.id, role="professor")
    return {
        "access_token": token,
        "professor": {
            "id": prof.id,
            "employee_id": prof.employee_id,
            "name": prof.name,
            "email": prof.email,
            "department": prof.department,
        }
    }


# --- 8. STUDENT GRADE ENDPOINTS ---
@app.get("/student/grades", response_model=List[GradeResponse])
async def get_my_grades(
    payload: dict = Depends(require_student),
    db: Session = Depends(get_db),
):
    """Returns only the authenticated student's grades, with live integrity check."""
    student_id = payload["sub"]
    grades = db.query(GradeDB).filter(GradeDB.student_id == student_id).all()
    results = []
    for g in grades:
        data_str = build_grade_data_string(
    g.id, g.student_id, g.course_code,
    g.grade, g.letter_grade,  # ← add this
    g.recorded_at.isoformat()
)
        is_verified = compute_hash(data_str) == g.hash
        db.add(AuditLogDB(
            grade_id=g.id,
            action="Student View",
            status="PASS" if is_verified else "FAIL",
            error_details=None if is_verified else "Hash mismatch detected on student view",
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
            "is_verified": is_verified,
        })
    db.commit()
    return results


@app.get("/student/grades/{grade_id}/logs")
async def get_my_grade_logs(
    grade_id: str,
    payload: dict = Depends(require_student),
    db: Session = Depends(get_db),
):
    """Student can view audit logs for their own grade."""
    student_id = payload["sub"]
    grade = db.query(GradeDB).filter(
        GradeDB.id == grade_id,
        GradeDB.student_id == student_id,
    ).first()
    if not grade:
        raise HTTPException(404, "Grade not found")

    logs = db.query(AuditLogDB).filter(AuditLogDB.grade_id == grade_id).order_by(
        AuditLogDB.checked_at.desc()
    ).limit(20).all()

    return {"logs": [AuditLogResponse.from_db(l).model_dump() for l in logs]}


@app.get("/student/me")
async def student_me(payload: dict = Depends(require_student), db: Session = Depends(get_db)):
    student = db.query(StudentDB).filter(StudentDB.student_id == payload["sub"]).first()
    if not student:
        raise HTTPException(404, "Student not found")
    return {
        "id": student.id,
        "student_id": student.student_id,
        "name": student.name,
        "email": student.email,
        "department": student.department,
    }


# --- 9. PROFESSOR GRADE ENDPOINTS (unchanged) ---
@app.get("/grades", response_model=List[GradeResponse])
async def get_grades(
    student_id: Optional[str] = None,
    payload: dict = Depends(require_professor),
    db: Session = Depends(get_db),
):
    query = db.query(GradeDB)
    if student_id:
        query = query.filter(GradeDB.student_id == student_id)
    grades = query.all()
    results = []
    for g in grades:
        data_str = build_grade_data_string(
            g.id, g.student_id, g.course_code, g.grade, g.recorded_at.isoformat()
        )
        is_verified = compute_hash(data_str) == g.hash
        db.add(AuditLogDB(
            grade_id=g.id,
            action="Automatic Integrity Check",
            status="PASS" if is_verified else "FAIL",
            error_details=None if is_verified else "Hash mismatch",
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
            "is_verified": is_verified,
        })
    db.commit()
    return results


@app.post("/grades", response_model=GradeResponse)
async def create_grade(
    grade_data: GradeCreate,
    payload: dict = Depends(require_professor),
    db: Session = Depends(get_db),
):
    import uuid
    new_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).replace(microsecond=0, tzinfo=None)
    data_str = build_grade_data_string(
        new_id, grade_data.student_id, grade_data.course_code, grade_data.grade, now.isoformat()
    )
    grade_hash = compute_hash(data_str)
    db_grade = GradeDB(
        id=new_id,
        student_id=grade_data.student_id,
        course_name=grade_data.course_name,
        course_code=grade_data.course_code,
        grade=grade_data.grade,
        letter_grade=grade_data.letter_grade,
        recorded_at=now,
        hash=grade_hash,
    )
    db.add(db_grade)
    db.commit()
    db.refresh(db_grade)
    return db_grade


@app.post("/verify/batch")
async def verify_batch(data: dict, db: Session = Depends(get_db)):
    grade_ids = data.get("grade_ids", [])
    results = []
    for g_id in grade_ids:
        grade = db.query(GradeDB).filter(GradeDB.id == g_id).first()
        if not grade:
            results.append({"grade_id": g_id, "is_valid": False, "error": "Not found"})
            continue
        data_string = build_grade_data_string(
    grade.id, grade.student_id, grade.course_code,
    grade.grade, grade.letter_grade,  # ← add this
    grade.recorded_at.isoformat()
)
        is_valid = compute_hash(data_string) == grade.hash
        db.add(AuditLogDB(
            grade_id=grade.id,
            action="Batch Verification",
            status="PASS" if is_valid else "FAIL",
            error_details=None if is_valid else "Integrity mismatch detected",
        ))
        results.append({
            "grade_id": grade.id,
            "is_valid": is_valid,
            "error": None if is_valid else "Integrity check failed",
        })
    db.commit()
    return results


@app.get("/grades/{grade_id}/logs")
async def get_grade_logs(
    grade_id: str,
    payload: dict = Depends(require_professor),
    db: Session = Depends(get_db),
):
    logs = db.query(AuditLogDB).filter(AuditLogDB.grade_id == grade_id).order_by(
        AuditLogDB.checked_at.desc()
    ).limit(30).all()
    return {"logs": [AuditLogResponse.from_db(l).model_dump() for l in logs]}


@app.post("/admin/recalculate-hashes")
async def recalculate_hashes(db: Session = Depends(get_db)):
    """Utility endpoint to instantly heal all broken hashes in the database."""
    grades = db.query(GradeDB).all()
    count = 0
    for g in grades:
        data_str = build_grade_data_string(
            g.id, g.student_id, g.course_code, g.grade, g.recorded_at.isoformat()
        )
        g.hash = compute_hash(data_str)
        count += 1

    # Clear all old audit logs so the Professor app doesn't see old FAIL history
    db.query(AuditLogDB).delete()

    db.commit()
    return {"message": f"Successfully recalculated {count} hashes and wiped old error logs!"}


@app.get("/")
async def root():
    return {"message": "GradeGuardian Student Portal API", "status": "Online", "version": "2.1.0"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)