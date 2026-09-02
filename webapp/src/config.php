<?php
// Widgetorium global configuration. Values come from the container environment
// (see docker-compose.yml / .env.example).

return [
    'db' => [
        'host' => getenv('DB_HOST') ?: 'db',
        'name' => getenv('DB_NAME') ?: 'widgetorium',
        'user' => getenv('DB_USER') ?: 'widgetorium',
        'pass' => getenv('DB_PASS') ?: 'widgetorium',
    ],
    // weakness toggles: "1" on, "0" off
    'verbose_errors'    => (getenv('VERBOSE_ERRORS') ?: '1') === '1',
    'second_order_sink' => (getenv('SECOND_ORDER_SINK') ?: '1') === '1',
    'weak_sessions'     => (getenv('WEAK_SESSIONS') ?: '1') === '1',
];
