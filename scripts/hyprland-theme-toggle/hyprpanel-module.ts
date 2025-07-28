import { Variable } from 'astal';
import { Gtk } from 'astal/gtk3';
import { execAsync, exec } from 'astal/process';

class ThemeToggle {
    private currentTheme: Variable<string> = Variable('dark');

    constructor() {
        this.getCurrentTheme();
    }

    private getCurrentTheme(): void {
        execAsync(['bash', '-c', 'cat ~/.cache/theme_state 2>/dev/null || echo "dark"'])
            .then(output => {
                this.currentTheme.set(output.trim());
            })
            .catch(err => {
                console.error('Failed to get current theme:', err);
                this.currentTheme.set('dark');
            });
    }

    private toggleTheme(): void {
        execAsync(['bash', '-c', '/home/mason/scripts/hyprland-theme-toggle/theme-toggle-modular.sh'])
            .then(() => {
                // Update the current theme state
                this.getCurrentTheme();
            })
            .catch(err => {
                console.error('Failed to toggle theme:', err);
            });
    }

    private getIcon(): string {
        return this.currentTheme.get() === 'light' ? '☀️' : '🌙';
    }

    private getTooltip(): string {
        const current = this.currentTheme.get();
        const next = current === 'light' ? 'dark' : 'light';
        return `Switch to ${next} mode (currently ${current})`;
    }

    public render(): Gtk.Widget {
        const button = new Gtk.Button({
            className: 'theme-toggle-button',
            tooltip_text: this.getTooltip(),
        });

        const label = new Gtk.Label({
            label: this.getIcon(),
        });

        button.child = label;

        // Update button when theme changes
        this.currentTheme.subscribe(() => {
            label.label = this.getIcon();
            button.tooltip_text = this.getTooltip();
        });

        button.connect('clicked', () => {
            this.toggleTheme();
        });

        return button;
    }
}

export default () => new ThemeToggle().render();