# TODO: Add Review Option and Improve UI Consistency

## Plan Summary
Add a review option in the customer's orders page for each order and order item, and improve UI consistency across all pages with a consistent theme.

## Steps to Complete

### 1. Create Review Page
- [x] Create `foodie_go/lib/customer/review_page.dart`
  - Add form with rating (1-5 stars), comment text field, submit button
  - Handle submission to 'reviews' table in Supabase
  - Use consistent app colors from constants.dart

### 2. Update Orders Page
- [x] Update `foodie_go/lib/customer/orders.dart`
  - Add "Review Order" button for delivered orders in ListTile
  - Navigate to ReviewPage with order_id on button press

### 3. Update Order Details Page
- [x] Update `foodie_go/lib/customer/order_details.dart`
  - Add "Review Item" button for each item
  - Navigate to ReviewPage with order_id and dish_id on button press

### 4. Improve UI Consistency
- [ ] Review and update UI in key pages for consistency:
  - `foodie_go/lib/customer/homepage.dart` ✅
  - `foodie_go/lib/customer/profile.dart`
  - `foodie_go/lib/customer/cart.dart`
  - `foodie_go/lib/customer/checkout.dart`
  - `foodie_go/lib/customer/restraunts.dart`
  - `foodie_go/lib/driver/driv_homepage.dart`
  - `foodie_go/lib/driver/driver_profile.dart`
  - `foodie_go/lib/restraunt/rest_homepage.dart`
  - `foodie_go/lib/restraunt/menu.dart`
  - `foodie_go/lib/restraunt/orders.dart`
  - `foodie_go/lib/restraunt/payments.dart`
  - `foodie_go/lib/restraunt/analytics_fixed.dart`
  - `foodie_go/lib/restraunt/reviews.dart`
- [ ] Ensure consistent use of AppColors, fonts, spacing, and layout

### 5. Testing and Verification
- [ ] Test review functionality
- [ ] Verify reviews appear in restaurant reviews page
- [ ] Check database schema for any issues
- [ ] Ensure UI consistency across all pages
