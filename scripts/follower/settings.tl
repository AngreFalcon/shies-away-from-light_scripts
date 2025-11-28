local I = require('openmw.interfaces')

I.Settings.registerPage {
    key = 'ShiesAwayFromLightPage',
    l10n = 'ShiesAwayFromLight',
    name = 'Shies-Away-from-Light',
    description = 'Page description TBD',
}

I.Settings.registerGroup {
    key = 'SettingsShiesAwayFromLight',
    page = 'ShiesAwayFromLightPage',
    l10n = 'ShiesAwayFromLight',
    name = 'Settings group name TBD',
    description = 'Group Description TBD',
    permanentStorage = false,
    settings = {
        {
            key = 'greeting',
            default = 'Hi',
            renderer = 'textLine',
            name = 'Text Input',
            description = 'Short text input',
        },
        {
            key = 'flag',
            default = false,
            renderer = 'checkbox',
            name = 'Flag',
            description = 'Flag toggle',
        },
        {
            key = 'number',
            renderer = 'number',
            name = 'Number',
            default = 4,
            min = 0,
            max = 10,
            description = 'Number input',
        }
        -- [[ see https://openmw.readthedocs.io/en/latest/reference/lua-scripting/setting_renderers.html ]]
    } as {I.Settings.SettingOptions},
}