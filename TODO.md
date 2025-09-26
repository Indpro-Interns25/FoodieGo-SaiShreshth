# Review System Fixes

## Backend Changes
- [x] Add /get_dish_rating endpoint in flask_backend/app.py
- [x] Add /get_restaurant_rating endpoint in flask_backend/app.py
- [x] Add optimized /get_top_dishes_with_ratings endpoint for faster loading

## Frontend Changes
- [x] Update foodie_go/lib/customer/home.dart to fetch and display dish ratings
- [x] Update foodie_go/lib/customer/home.dart to fetch and display restaurant ratings
- [x] Update foodie_go/lib/customer/order_details.dart to only show review buttons for delivered orders
- [x] Update foodie_go/lib/customer/review_page.dart to require dishId and fix title
- [x] Update home.dart to use optimized endpoint that loads ratings simultaneously

## Performance Optimizations
- [x] Optimized dish rating calculation by fetching all reviews for top dishes in one query
- [x] Combined top ordered dishes and ratings loading into single API call
- [x] Reduced database queries from N+1 to 2 queries for top dishes with ratings

## Testing
- [ ] Test per-item reviews for completed orders
- [ ] Test dish rating display in home page
- [ ] Test restaurant average rating display
- [ ] Test improved loading performance of top dishes section
