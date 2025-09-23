import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class IntroductionPage extends StatefulWidget {
  final VoidCallback onComplete;
  const IntroductionPage({super.key,
  required this.onComplete});

  @override
  State<IntroductionPage> createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<IntroSlide> _slides = [
    IntroSlide(
      title: 'Welcome to FoodieGo!',
      description: 'Your one-stop solution for food delivery.',
      image: 'assets/intro1.png',
      color: const Color.fromARGB(255, 243, 105, 77),
    ),
    IntroSlide(
      title: 'Easy Ordering',
      description: 'Order from your favorite restaurants with just a few taps.',
      image: 'assets/intro2.png',
      color: const Color.fromARGB(255, 255, 150, 102),
    ),
    IntroSlide(
      title: 'Fast Delivery',
      description: 'Get your food delivered quickly by our delivery partners.',
      image: 'assets/intro3.png',
      color: const Color.fromARGB(255, 212, 179, 156),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              return _buildSlide(_slides[index]);
            },
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildPageIndicator(),
                ),
                const SizedBox(height: 20),
                if (_currentPage == _slides.length - 1)
                  ElevatedButton(
                    onPressed: () => _completeIntroduction(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(IntroSlide slide) {
    return Container(
      color: slide.color,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            slide.image,
            height: 300,
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageIndicator() {
    List<Widget> indicators = [];
    for (int i = 0; i < _slides.length; i++) {
      indicators.add(
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == _currentPage ? Colors.white : Colors.white.withOpacity(0.4),
          ),
        ),
      );
    }
    return indicators;
  }

  Future<void> _completeIntroduction(BuildContext context) async {
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('has_seen_intro', true);
    // if (context.mounted) {
    //   Navigator.pushReplacementNamed(context, '/homepage');
    // }
    widget.onComplete();
  }
}

class IntroSlide {
  final String title;
  final String description;
  final String image;
  final Color color;

  IntroSlide({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
  });
}