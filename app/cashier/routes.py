
from flask import Blueprint, render_template, request, redirect, url_for, flash
from .. import db
from ..models import Order, OrderStatus

cashier_bp = Blueprint('cashier', __name__)

@cashier_bp.route('/cashier', methods=['GET', 'POST'])
def cashier():
    if request.method == 'POST':
        customer_name = request.form.get('customer_name')
        drink = request.form.get('drink')
        size = request.form.get('size')
        notes = request.form.get('notes')
        if not customer_name or not drink or not size:
            flash('Please fill in customer name, drink, and size.')
        else:
            order = Order(customer_name=customer_name, drink=drink, size=size, notes=notes)
            db.session.add(order)
            db.session.commit()
            flash('Order created!')
            return redirect(url_for('cashier.cashier'))
    # Show recent orders
    orders = Order.query.order_by(Order.created_at.desc()).limit(20).all()
    return render_template('cashier.html', orders=orders)
