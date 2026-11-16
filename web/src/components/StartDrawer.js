// Start-edge navigation adapter: SDK 0.5.0 Drawer exposes no placement prop.
// Same verified modal lifecycle, focus and motion implementation; public imports.
/*
MIT License

Copyright (c) 2026 Rosemary contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useId, useRef } from "react";
import { motion } from "@rosemary-ui/tokens";
import { IconButton, useRosemaryTheme, useRosemaryStrings } from "@rosemary-ui/react";
function focusConnected(element) {
    if (element?.isConnected &&
        !element.closest("[inert]") &&
        !element.hasAttribute("disabled"))
        element.focus();
}
export function StartDrawer({ open, onOpenChange, title, description, children, footer, closeLabel, closeOnOutside = false, modal = true, onAnimationComplete, className, returnFocusRef, drawer = true, }) {
    const { direction, reducedMotion } = useRosemaryTheme();
    const strings = useRosemaryStrings();
    const ref = useRef(null);
    const id = useId();
    const restore = useRef(null);
    const shownModal = useRef(null);
    const complete = useRef(onAnimationComplete);
    complete.current = onAnimationComplete;
    const snapshot = useRef(null);
    useEffect(() => {
        const element = ref.current;
        if (!element)
            return;
        let current = true;
        const animations = [];
        if (open && !element.open) {
            restore.current =
                returnFocusRef?.current ??
                    (document.activeElement instanceof HTMLElement
                        ? document.activeElement
                        : null);
            modal ? element.showModal() : element.show();
            shownModal.current = modal;
        }
        else if (open && shownModal.current !== modal) {
            const active = document.activeElement instanceof HTMLElement &&
                element.contains(document.activeElement)
                ? document.activeElement
                : null;
            element.close();
            modal ? element.showModal() : element.show();
            shownModal.current = modal;
            focusConnected(active);
        }
        if (!open && !element.open)
            return;
        const finish = () => {
            if (!current)
                return;
            if (!open && element.open) {
                element.close();
                shownModal.current = null;
                focusConnected(restore.current);
            }
            complete.current?.(open);
        };
        if (element.open &&
            !reducedMotion &&
            typeof element.animate === "function") {
            const sign = direction === "rtl" ? 1 : -1;
            const previous = snapshot.current;
            snapshot.current = null;
            const start = previous ?? {
                transform: open
                    ? drawer
                        ? `translateX(${sign * 100}%)`
                        : "translateY(8px) scale(.98)"
                    : "translateX(0)",
                opacity: open ? "0" : "1",
                backdrop: open ? "transparent" : "rgba(27,20,40,.325)",
            };
            animations.push(element.animate([
                { transform: start.transform, opacity: start.opacity },
                {
                    transform: open
                        ? "translateX(0)"
                        : drawer
                            ? `translateX(${sign * 100}%)`
                            : "translateY(8px) scale(.98)",
                    opacity: open ? 1 : 0,
                },
            ], {
                duration: drawer
                    ? open
                        ? motion.drawerEnterMs
                        : motion.drawerExitMs
                    : open
                        ? motion.transition
                        : motion.exit,
                easing: motion.easing,
                fill: "both",
            }));
            if (modal) {
                try {
                    animations.push(element.animate([
                        { backgroundColor: start.backdrop },
                        {
                            backgroundColor: open ? "rgba(27,20,40,.325)" : "transparent",
                        },
                    ], {
                        duration: drawer
                            ? open
                                ? motion.drawerEnterMs
                                : motion.drawerExitMs
                            : open
                                ? motion.transition
                                : motion.exit,
                        easing: motion.easing,
                        fill: "both",
                        pseudoElement: "::backdrop",
                    }));
                }
                catch {
                    /* The panel animation remains authoritative when pseudo-element WAAPI is unsupported. */
                }
            }
            Promise.all(animations.map((animation) => animation.finished)).then(finish, () => { });
        }
        else {
            snapshot.current = null;
            finish();
        }
        return () => {
            current = false;
            if (animations.length) {
                const computed = getComputedStyle(element);
                snapshot.current = {
                    transform: computed.transform,
                    opacity: computed.opacity,
                    backdrop: getComputedStyle(element, "::backdrop").backgroundColor,
                };
                animations.forEach((animation) => animation.cancel());
            }
        };
    }, [open, drawer, reducedMotion, direction, modal]);
    useEffect(() => {
        const element = ref.current;
        return () => {
            if (element?.open)
                element.close();
            focusConnected(restore.current);
        };
    }, []);
    return (_jsxs("dialog", { ref: ref, className: ["rm-dialog", drawer ? "rm-drawer" : "", className]
            .filter(Boolean)
            .join(" "), "aria-modal": modal || undefined, "aria-labelledby": `${id}-title`, "aria-describedby": description ? `${id}-description` : undefined, onKeyDownCapture: (e) => {
            if (!modal ||
                e.key !== "Tab" ||
                e.target.closest("dialog") !== e.currentTarget)
                return;
            const candidates = Array.from(e.currentTarget.querySelectorAll("button, a[href], input, textarea, select, [tabindex]")).filter((element) => element.tabIndex >= 0 &&
                !element.hasAttribute("disabled") &&
                !element.closest("[hidden], [inert]") &&
                getComputedStyle(element).display !== "none" &&
                getComputedStyle(element).visibility !== "hidden");
            const first = candidates[0], last = candidates[candidates.length - 1];
            if (!first) {
                e.preventDefault();
                e.currentTarget.focus();
                return;
            }
            if (e.shiftKey &&
                (document.activeElement === first ||
                    document.activeElement === e.currentTarget)) {
                e.preventDefault();
                last?.focus();
            }
            else if (!e.shiftKey && document.activeElement === last) {
                e.preventDefault();
                first.focus();
            }
        }, onCancel: (e) => {
            e.preventDefault();
            onOpenChange(false, "escape");
        }, onClick: (e) => {
            if (closeOnOutside && e.target === e.currentTarget) {
                const b = e.currentTarget.getBoundingClientRect();
                if (e.clientX < b.left ||
                    e.clientX > b.right ||
                    e.clientY < b.top ||
                    e.clientY > b.bottom)
                    onOpenChange(false, "outside");
            }
        }, children: [_jsxs("header", { children: [_jsx("h2", { id: `${id}-title`, children: title }), _jsx(IconButton, { variant: "ghost", icon: "close", label: closeLabel ?? strings.close, onClick: () => onOpenChange(false, "cancel") })] }), description && (_jsx("p", { id: `${id}-description`, className: "rm-help", children: description })), _jsx("div", { className: "rm-dialog-body", children: children }), footer && _jsx("footer", { children: footer })] }));
}
