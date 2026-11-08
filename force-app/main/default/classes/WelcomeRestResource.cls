@RestResource(urlMapping='/welcome')
/**
 * WelcomeRestResource
 *
 * REST resource exposing a simple GET endpoint that returns a welcome message.
 * This class is global and uses "with sharing" to enforce sharing rules.
 */
global with sharing class WelcomeRestResource {

    @HttpGet
    /**
     * Returns a welcome message for the REST resource.
     *
     * @return A string containing the welcome message.
     */
    global static String welcomeMessage() {
        return 'Welcome to Rest Resource with Hanu';
    }
}