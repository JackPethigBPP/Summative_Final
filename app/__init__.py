
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from .config import Config

db = SQLAlchemy()


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    @app.route("/healthz", methods=["GET"])
    def healthz():
        return "OK", 200

    db.init_app(app)

    # Ensure tables exist
    with app.app_context():
        from . import models  # noqa
        db.create_all()

    # Blueprints
    from .cashier.routes import cashier_bp
    from .barista.routes import barista_bp
    from .api.routes import api_bp
    app.register_blueprint(cashier_bp)
    app.register_blueprint(barista_bp)
    app.register_blueprint(api_bp, url_prefix="/api")

    @app.route("/")
    def index():
        from flask import redirect, url_for
        return redirect(url_for("cashier.cashier"))

    return app
