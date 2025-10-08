import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int currentStep = 0;
  String selectedMode = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade600],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                Container(
                  margin: const EdgeInsets.only(top: 40, bottom: 60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 80,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Welcome to Medicore',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Medical Records Management',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _buildCurrentStep(),
                ),

                // Navigation buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildModeSelectionStep();
      case 1:
        return _buildConfirmationStep();
      default:
        return Container();
    }
  }

  Widget _buildModeSelectionStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Choose Your Setup Mode',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),
        Text(
          'Select how you want to use Medicore',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 40),
        
        // Cloud option
        _buildModeOption(
          mode: 'cloud',
          title: 'Use Cloud',
          subtitle: 'Sync data across devices with cloud storage',
          icon: Icons.cloud,
          isEnabled: false, // Disabled for now
        ),
        
        SizedBox(height: 20),
        
        // Solo option
        _buildModeOption(
          mode: 'solo',
          title: 'Use Solo',
          subtitle: 'Store data locally on this device only',
          icon: Icons.storage,
          isEnabled: true,
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
  }) {
    bool isSelected = selectedMode == mode;
    
    return GestureDetector(
      onTap: isEnabled ? () {
        setState(() {
          selectedMode = mode;
        });
      } : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected 
            ? Colors.white 
            : Colors.white.withOpacity(isEnabled ? 0.9 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.blue.shade200,
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                  ? Colors.blue.shade600 
                  : (isEnabled ? Colors.blue.shade100 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected 
                  ? Colors.white 
                  : (isEnabled ? Colors.blue.shade600 : Colors.grey.shade600),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isEnabled ? Colors.black87 : Colors.grey.shade600,
                        ),
                      ),
                      if (!isEnabled) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Coming Soon',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled ? Colors.black54 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue.shade600,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 80,
          color: Colors.white,
        ),
        SizedBox(height: 24),
        Text(
          'Setup Complete!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        Text(
          'Medicore is configured to work in ${selectedMode == 'solo' ? 'Solo' : 'Cloud'} mode.\nYou can start managing patient records now.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      margin: EdgeInsets.only(top: 40),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    currentStep--;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          
          if (currentStep > 0) SizedBox(width: 16),
          
          Expanded(
            child: ElevatedButton(
              onPressed: _getNextButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade600,
                padding: EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: Text(
                _getNextButtonText(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getNextButtonAction() {
    switch (currentStep) {
      case 0:
        return selectedMode.isNotEmpty ? () {
          setState(() {
            currentStep++;
          });
        } : null;
      case 1:
        return () => _completeSetup();
      default:
        return null;
    }
  }

  String _getNextButtonText() {
    switch (currentStep) {
      case 0:
        return 'Continue';
      case 1:
        return 'Get Started';
      default:
        return 'Next';
    }
  }

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Store setup completion and selected mode
    await prefs.setBool('setup_completed', true);
    await prefs.setString('app_mode', selectedMode);
    await prefs.setInt('setup_version', 1); // For future migrations
    
    // Navigate to main app
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }
}