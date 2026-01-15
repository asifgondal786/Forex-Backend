"""
Example of how to integrate live updates into your backend tasks
"""
from fastapi import APIRouter, BackgroundTasks
from .websocket_manager import live_update_service
import asyncio
import uuid

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


# Example 1: Simple task with live updates
@router.post("/process-data")
async def process_data(background_tasks: BackgroundTasks):
    """Example endpoint that processes data with live updates"""
    task_id = str(uuid.uuid4())
    
    # Start background task
    background_tasks.add_task(process_data_task, task_id)
    
    return {
        "task_id": task_id,
        "message": "Processing started. Connect to WebSocket for updates."
    }


async def process_data_task(task_id: str):
    """Background task that sends live updates"""
    try:
        # Step 1: Initial update
        await live_update_service.send_info(task_id, "Starting data processing...")
        await asyncio.sleep(1)
        
        # Step 2: Progress update
        await live_update_service.send_progress(task_id, "Loading data...", 0.2)
        await asyncio.sleep(2)
        
        # Step 3: More progress
        await live_update_service.send_progress(task_id, "Processing records...", 0.5)
        await asyncio.sleep(2)
        
        # Step 4: Warning (optional)
        await live_update_service.send_warning(task_id, "Found 3 invalid records, skipping...")
        await asyncio.sleep(1)
        
        # Step 5: Near completion
        await live_update_service.send_progress(task_id, "Finalizing...", 0.9)
        await asyncio.sleep(1)
        
        # Step 6: Success
        await live_update_service.send_success(task_id, "Processing completed successfully! Processed 1,247 records.")
        
    except Exception as e:
        await live_update_service.send_error(task_id, f"Processing failed: {str(e)}")


# Example 2: File upload with progress tracking
@router.post("/upload-file")
async def upload_file(background_tasks: BackgroundTasks):
    """Example file upload with progress updates"""
    task_id = str(uuid.uuid4())
    
    background_tasks.add_task(upload_file_task, task_id)
    
    return {"task_id": task_id}


async def upload_file_task(task_id: str):
    """Simulates file upload with progress"""
    try:
        await live_update_service.send_info(task_id, "Starting upload...")
        
        # Simulate chunked upload
        chunks = 10
        for i in range(chunks):
            progress = (i + 1) / chunks
            await live_update_service.send_progress(
                task_id,
                f"Uploading... {int(progress * 100)}%",
                progress
            )
            await asyncio.sleep(0.5)
        
        await live_update_service.send_success(task_id, "Upload completed!")
        
    except Exception as e:
        await live_update_service.send_error(task_id, f"Upload failed: {str(e)}")


# Example 3: Analysis task with multiple steps
@router.post("/analyze")
async def analyze_data(background_tasks: BackgroundTasks):
    """Example complex analysis with multiple update stages"""
    task_id = str(uuid.uuid4())
    
    background_tasks.add_task(analyze_task, task_id)
    
    return {"task_id": task_id}


async def analyze_task(task_id: str):
    """Multi-step analysis with detailed updates"""
    try:
        # Stage 1
        await live_update_service.send_info(task_id, "Initializing analysis...")
        await asyncio.sleep(1)
        
        # Stage 2
        await live_update_service.send_progress(task_id, "Collecting data from sources...", 0.1)
        await asyncio.sleep(2)
        
        # Stage 3
        await live_update_service.send_progress(task_id, "Running statistical analysis...", 0.3)
        await asyncio.sleep(3)
        
        # Stage 4
        await live_update_service.send_progress(task_id, "Generating visualizations...", 0.6)
        await asyncio.sleep(2)
        
        # Stage 5
        await live_update_service.send_progress(task_id, "Creating report...", 0.8)
        await asyncio.sleep(2)
        
        # Complete
        await live_update_service.send_success(
            task_id,
            "Analysis complete! Report generated with 15 insights."
        )
        
    except Exception as e:
        await live_update_service.send_error(task_id, f"Analysis failed: {str(e)}")


# Example 4: How to use in synchronous code
def sync_function_example(task_id: str):
    """If you need to send updates from sync code"""
    import asyncio
    
    # Create event loop if needed
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    
    # Send update
    loop.run_until_complete(
        live_update_service.send_info(task_id, "Update from sync function")
    )