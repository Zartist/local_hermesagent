<?php
/**
 * Database upgrades
 *
 * @package    local_hermesagent
 * @copyright  2026
 * @license    https://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

function xmldb_local_hermesagent_upgrade($oldversion) {
    global $DB;

    $dbman = $DB->get_manager();

    if ($oldversion < 2026061200) {
        // Insert default settings on first upgrade
        $defaults = [
            ['name' => 'bridge_port', 'value' => '9118', 'description' => 'Local port for ACP bridge'],
            ['name' => 'hermes_model', 'value' => '', 'description' => 'Override model for this plugin'],
            ['name' => 'hermes_home', 'value' => '', 'description' => 'Custom HERMES_HOME path'],
            ['name' => 'bridge_status', 'value' => 'stopped', 'description' => 'Bridge status'],
            ['name' => 'last_schema_refresh', 'value' => '0', 'description' => 'Last schema refresh timestamp'],
        ];

        foreach ($defaults as $setting) {
            if (!$DB->record_exists('local_hermesagent_settings', ['name' => $setting['name']])) {
                $record = (object)[
                    'name' => $setting['name'],
                    'value' => $setting['value'],
                    'description' => $setting['description'],
                    'timemodified' => time(),
                ];
                $DB->insert_record('local_hermesagent_settings', $record);
            }
        }

        upgrade_plugin_savepoint(true, 2026061200, 'local', 'hermesagent');
    }

    return true;
}
