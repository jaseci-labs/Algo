# Algo - Personal AI Assistant with Authentication

Algo is a voice-enabled personal AI assistant with calendar, email, and GitHub integration. It features a complete authentication system with login/register pages.

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/jaseci-labs/Algo.git
   cd Algo
   ```

2. **Set up your API key**
   
   Create a .env file or set environment variable:
   ```bash
   export OPENAI_API_KEY='your-api-key-here'
   ```

4. **Start the application**
   ```bash
   jac start main.jac
   ```

5. **Open your browser**
   
   Navigate to http://localhost:8000

### Authentication

The app now includes a complete authentication system:

- **Register**: Create a new account at `/register`
- **Login**: Access your account at `/login`
- **Protected Routes**: The main app interface at `/app` is only accessible after authentication
- **Logout**: Click the logout button in the header to sign out

**First-time users** will be redirected to the login page. Click "Sign up" to create an account.

### Features

- 🎙️ Voice-enabled interface with OpenAI Realtime API
- 📅 Calendar integration for meeting management
- 📧 Email viewing and management
- 💻 GitHub issue tracking
- 📊 Real-time task graph visualization
- 🔐 Secure authentication system

