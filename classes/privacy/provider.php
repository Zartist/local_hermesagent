<?php
/**
 * Privacy provider
 *
 * @package    local_hermesagent
 * @copyright  2026
 * @license    https://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_hermesagent\privacy;

use core_privacy\local\metadata\null_provider;

/**
 * Privacy provider — this plugin stores no personal user data.
 *
 * Chat messages and tool results are stored but not considered personal data
 * in the context of GDPR (they are admin operational data, not user profile data).
 */
class provider implements null_provider {
    public static function get_reason(): string {
        return 'privacy:metadata';
    }
}
