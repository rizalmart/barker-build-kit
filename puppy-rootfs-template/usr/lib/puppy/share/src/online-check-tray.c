// monitor online internet connectivity
// compile: gcc -o online-check-tray `pkg-config --cflags --libs gtk+-3.0 appindicator3-0.1 glib-2.0 libcurl` online-check-tray.c

#include <gtk/gtk.h>
#include <libappindicator/app-indicator.h>
#include <glib.h>
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

typedef struct {
    AppIndicator *indicator;
    char *last_status;
    int gc_tick;
    int status_tick;
    const char *check_url;
} OnlineIndicator;

void update_status(OnlineIndicator *online);
void *start_periodic_check(void *online_ptr);
char *get_online_status(OnlineIndicator *online);
void quit(GtkWidget *widget, gpointer data);
GtkWidget *build_menu(OnlineIndicator *online);

int main(int argc, char **argv) {
    gtk_init(&argc, &argv);

    OnlineIndicator *online = g_new0(OnlineIndicator, 1);
    online->check_url = "http://www.msftncsi.com/ncsi.txt";
    online->last_status = g_strdup("");
    online->gc_tick = 0;
    online->status_tick = 0;

    // Initialize AppIndicator
    online->indicator = app_indicator_new("weather-overcast-symbolic", "weather-overcast-symbolic", APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
    app_indicator_set_title(online->indicator, "Online Status");
    app_indicator_set_status(online->indicator, APP_INDICATOR_STATUS_ACTIVE);
    app_indicator_set_menu(online->indicator, GTK_MENU(build_menu(online)));

    // Periodically check online status
    update_status(online);

    // Start periodic check in a separate thread
    pthread_t status_check_thread;
    pthread_create(&status_check_thread, NULL, start_periodic_check, online);
    pthread_detach(status_check_thread);

    gtk_main();
    return 0;
}

GtkWidget *build_menu(OnlineIndicator *online) {
    GtkWidget *menu = gtk_menu_new();

    // Add quit option
    GtkWidget *quit_item = gtk_menu_item_new_with_label("Quit");
    g_signal_connect(quit_item, "activate", G_CALLBACK(quit), NULL);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);

    gtk_widget_show_all(menu);
    return menu;
}

void quit(GtkWidget *widget, gpointer data) {
    gtk_main_quit();
}

char *get_online_status(OnlineIndicator *online) {
    CURL *curl;
    CURLcode res;
    char *status = g_strdup("offline");

    curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, online->check_url);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5L);
        curl_easy_setopt(curl, CURLOPT_NOBODY, 1L); // We don't need body, just the status

        res = curl_easy_perform(curl);
        if (res == CURLE_OK) {
            status = g_strdup("online");
        }

        curl_easy_cleanup(curl);
    }
    return status;
}

void update_status(OnlineIndicator *online) {
    char *status = get_online_status(online);

    if (g_strcmp0(online->last_status, status) != 0) {
        g_free(online->last_status);
        online->last_status = g_strdup(status);

        if (g_strcmp0(status, "online") == 0) {
            app_indicator_set_icon_full(online->indicator, "weather-overcast-symbolic", "Connected to the internet");
        } else {
            app_indicator_set_icon_full(online->indicator, "weather-severe-alert-symbolic", "No internet connection");
        }
    }

    g_free(status);
}

void *start_periodic_check(void *online_ptr) {
    OnlineIndicator *online = (OnlineIndicator *)online_ptr;

    while (1) {
        online->status_tick += 1;
        if (online->status_tick == 3) {
            g_idle_add((GSourceFunc)update_status, online);
            online->status_tick = 0;
        }

        online->gc_tick += 1;
        if (online->gc_tick == 30) {
            //g_collect();
            online->gc_tick = 0;
        }

        sleep(10);
    }
}
