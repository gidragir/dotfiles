# 🌐 Vivaldi Browser Configuration

## Native Desktop Notifications

Vivaldi reads persistent user flags from `~/.config/vivaldi-stable.conf`. This file is managed in dotfiles via GNU Stow (`vivaldi/.config/vivaldi-stable.conf`) and persists across system-wide browser updates.

### Configuration File: `~/.config/vivaldi-stable.conf`

```bash
VIVALDI_USER_FLAGS="--enable-native-notifications"
```

### Direct URL Flag Verification

You can also check or toggle native notification settings directly in the browser by visiting:

```
vivaldi://flags/#enable-native-notifications
```