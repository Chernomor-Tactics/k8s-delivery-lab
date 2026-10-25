import os

from fastapi import FastAPI

app = FastAPI(title="Task API")
APP_VERSION = os.getenv("APP_VERSION", "dev")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/version")
def version():
    return {"version": APP_VERSION}

from uuid import UUID, uuid4

from fastapi import HTTPException, status
from pydantic import BaseModel, Field


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class Task(BaseModel):
    id: UUID
    title: str
    completed: bool = False


tasks: dict[UUID, Task] = {}


@app.post("/tasks", response_model=Task, status_code=status.HTTP_201_CREATED)
def create_task(data: TaskCreate):
    task = Task(id=uuid4(), title=data.title)
    tasks[task.id] = task
    return task


@app.get("/tasks", response_model=list[Task])
def list_tasks():
    return list(tasks.values())


@app.get("/tasks/{task_id}", response_model=Task)
def get_task(task_id: UUID):
    task = tasks.get(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: UUID):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    del tasks[task_id]