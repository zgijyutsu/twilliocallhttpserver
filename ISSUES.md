# Issues

## Issue 1: 認証情報が平文で送信されるセキュリティリスク

- **Title**: Security Risk of Sending Credentials in Plain Text
- **Description**: The current implementation uses HTTP Basic Authentication, which only Base64-encodes the username and password without encryption. If the application is not protected by HTTPS (TLS), credentials are sent in plain text over the network, making them vulnerable to eavesdropping by a man-in-the-middle attack.
- **Suggestions**:
  - **Short-term**: Strongly recommend in the `README.md` that the application be run behind a reverse proxy (e.g., Nginx, Traefik) that provides TLS and forces HTTPS communication.
  - **Long-term**: Consider migrating to a more secure authentication mechanism (e.g., Bearer Token Authentication, OAuth2).

## Issue 2: Unintentional Information Disclosure Through Detailed Error Messages

- **Title**: Unintentional Information Disclosure Through Detailed Error Messages
- **Description**: Currently, when a server-side exception occurs, the detailed content of the exception object is returned directly to the client. This may contain information that could be useful for an attacker, such as library versions or the internal structure of the code.
- **Suggestions**: In a production environment (`debug=False`), standardize error messages to a generic message like "Internal Server Error" and log the detailed error content only on the server.
