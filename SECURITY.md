# Security Policy

## Supported versions

SafeAwake is currently pre-1.0 software. Security fixes are applied to the latest release and the `main` branch.

## Reporting a vulnerability

Please do not include passwords, access tokens, personal files, or other sensitive information in a public Issue. Open a minimal Issue asking for a private contact path, or use GitHub's private vulnerability reporting feature when it is enabled for the repository.

## Security model

SafeAwake does not require administrator access, does not bypass lid-close sleep, does not modify persistent power settings, and does not collect telemetry. A keep-awake assertion exists only while the app process is running and the user has explicitly enabled it.
