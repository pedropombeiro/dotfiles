# Ranger theme
# Mod of Spacecolors
# Reference: https://github.com/morhetz/gruvbox/blob/master/colors/gruvbox.vim#L89

from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import *

class Gruvbox(ColorScheme):
    def use(self, context):
        fg, bg, attr = default_colors

        if context.reset:
            pass

        elif context.in_browser:
            if context.selected:
                attr = reverse
            else:
                attr = normal
            if context.empty or context.error:
                bg = 124
            if context.border:
                attr |= bold
                fg = 245
            if context.media:
                if context.image:
                    fg = 172
                else:
                    fg = 106
            if context.container:
                attr |= bold
                fg = 132
            if context.directory:
                attr |= bold
                fg = 24
            elif context.executable and not \
                    any((context.media, context.container,
                        context.fifo, context.socket)):
                attr |= bold
                fg = 106
            if context.socket:
                fg = 132
            if context.fifo or context.device:
                fg = 172
                if context.device:
                    attr |= bold
            if context.link:
                fg = context.good and 72 or 175
            if context.tag_marker and not context.selected:
                attr |= bold
                if fg in (124, 132):
                    fg = 229
                else:
                    fg = 167
            if not context.selected and (context.cut or context.copied):
                fg = 235
                attr |= bold
            if context.main_column:
                if context.selected:
                    attr |= normal
                if context.marked:
                    attr |= bold
                    fg = 172
            if context.badinfo:
                if attr & reverse:
                    bg = 132
                else:
                    fg = 132

        elif context.in_titlebar:
            attr |= bold
            if context.hostname:
                attr |= bold
                fg = context.bad and 124 or 208
            elif context.directory:
                fg = 72
            elif context.tab:
                if context.good:
                    bg = 106
            elif context.link:
                fg = 108

        elif context.in_statusbar:
            if context.permissions:
                if context.good:
                    fg = 72
                elif context.bad:
                    fg = 124
            if context.marked:
                attr |= bold | reverse
                fg = 172
            if context.message:
                if context.bad:
                    attr |= bold
                    fg = 124

        if context.text:
            if context.highlight:
                attr |= reverse

        if context.in_taskview:
            if context.title:
                fg = 66

            if context.selected:
                attr |= reverse

        return fg, bg, attr
