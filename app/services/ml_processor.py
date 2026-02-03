"""
ML Model Processor with Live Updates
"""
import asyncio
import uuid
import numpy as np
from datetime import datetime
from typing import Dict, Optional
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

from app.models.live_update import LiveUpdate, UpdateType
from app.services.connection_manager import manager


class MLProcessor:
    def __init__(self):
        self.models: Dict[str, any] = {}
    
    async def send_live_update(
        self, 
        task_id: str, 
        message: str, 
        update_type: UpdateType,
        progress: Optional[float] = None
    ):
        """Send live update through WebSocket"""
        update = LiveUpdate(
            id=str(uuid.uuid4()),
            task_id=task_id,
            message=message,
            type=update_type,
            timestamp=datetime.utcnow().isoformat() + "Z",
            progress=progress
        )
        await manager.send_update(task_id, update)
        await asyncio.sleep(0.1)  # Small delay for UI updates
    
    async def train_model(self, task_id: str, data: Dict):
        """Train ML model with live progress updates"""
        try:
            await self.send_live_update(
                task_id, 
                "🚀 Starting model training...", 
                UpdateType.INFO,
                0.0
            )
            
            # Generate or use provided data
            if not data or "X" not in data:
                await self.send_live_update(
                    task_id,
                    "📊 Generating sample dataset...",
                    UpdateType.INFO,
                    0.1
                )
                X = np.random.randn(1000, 10)
                y = (X[:, 0] + X[:, 1] > 0).astype(int)
            else:
                X = np.array(data["X"])
                y = np.array(data["y"])
            
            await self.send_live_update(
                task_id,
                f"📈 Dataset loaded: {X.shape[0]} samples, {X.shape[1]} features",
                UpdateType.INFO,
                0.2
            )
            
            # Split data
            await self.send_live_update(
                task_id,
                "✂️ Splitting data into train/test sets (80/20)...",
                UpdateType.INFO,
                0.3
            )
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )
            
            # Initialize model
            await self.send_live_update(
                task_id,
                "🌲 Initializing Random Forest model (100 estimators)...",
                UpdateType.INFO,
                0.4
            )
            model = RandomForestClassifier(
                n_estimators=100,
                random_state=42,
                verbose=0
            )
            
            # Training with progress updates
            await self.send_live_update(
                task_id,
                "⚙️ Training model (this may take a moment)...",
                UpdateType.PROGRESS,
                0.5
            )
            
            # Simulate training progress
            for i in range(5):
                await asyncio.sleep(0.5)
                progress = 0.5 + (i + 1) * 0.08
                await self.send_live_update(
                    task_id,
                    f"🔄 Training progress: {int((i+1)*20)}% complete",
                    UpdateType.PROGRESS,
                    progress
                )
            
            model.fit(X_train, y_train)
            
            # Evaluate
            await self.send_live_update(
                task_id,
                "📊 Evaluating model performance...",
                UpdateType.INFO,
                0.9
            )
            
            train_score = model.score(X_train, y_train)
            test_score = model.score(X_test, y_test)
            
            # Store model
            self.models[task_id] = {
                'model': model,
                'train_score': train_score,
                'test_score': test_score,
                'n_samples': X.shape[0],
                'n_features': X.shape[1]
            }
            
            await self.send_live_update(
                task_id,
                f"✅ Training complete! Train: {train_score:.3f}, Test: {test_score:.3f}",
                UpdateType.SUCCESS,
                1.0
            )
            
        except Exception as e:
            await self.send_live_update(
                task_id,
                f"❌ Training failed: {str(e)}",
                UpdateType.ERROR,
                None
            )
    
    async def predict(self, task_id: str, data: Dict):
        """Make predictions with live updates"""
        try:
            await self.send_live_update(
                task_id,
                "🔍 Loading model for prediction...",
                UpdateType.INFO,
                0.0
            )
            
            if task_id not in self.models:
                await self.send_live_update(
                    task_id,
                    "⚠️ No trained model found. Please train a model first.",
                    UpdateType.ERROR,
                    None
                )
                return
            
            model_data = self.models[task_id]
            model = model_data['model']
            
            await self.send_live_update(
                task_id,
                "📥 Processing input data...",
                UpdateType.INFO,
                0.3
            )
            
            # Use provided data or generate sample
            if data and "X" in data:
                X = np.array(data["X"])
            else:
                X = np.random.randn(10, model_data['n_features'])
            
            await self.send_live_update(
                task_id,
                f"🎯 Making predictions for {len(X)} samples...",
                UpdateType.PROGRESS,
                0.6
            )
            
            predictions = model.predict(X)
            probabilities = model.predict_proba(X)
            
            # Format results
            results = {
                'predictions': predictions.tolist(),
                'probabilities': probabilities.tolist(),
                'n_samples': len(X)
            }
            
            await self.send_live_update(
                task_id,
                f"✅ Predictions complete! {len(predictions)} results generated.",
                UpdateType.SUCCESS,
                1.0
            )
            
            return results
            
        except Exception as e:
            await self.send_live_update(
                task_id,
                f"❌ Prediction failed: {str(e)}",
                UpdateType.ERROR,
                None
            )
    
    def has_model(self, task_id: str) -> bool:
        """Check if model exists for task"""
        return task_id in self.models
    
    def get_model_info(self, task_id: str) -> Optional[Dict]:
        """Get model information"""
        if task_id in self.models:
            model_data = self.models[task_id]
            return {
                'train_score': model_data['train_score'],
                'test_score': model_data['test_score'],
                'n_samples': model_data['n_samples'],
                'n_features': model_data['n_features']
            }
        return None


# Global instance
ml_processor = MLProcessor()