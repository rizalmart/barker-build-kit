//monitor ufw status
//compile command: gcc -o ufw_monitor `pkg-config --cflags --libs gtk+-3.0 appindicator3-0.1 glib-2.0` ufw_monitor.c

#include <gtk/gtk.h>
#include <libappindicator/app-indicator.h>
#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

typedef struct {
    AppIndicator *indicator;
    char *active_icon_name;
    char *last_status;
    int gc_tick;
    int status_tick;
} UfwIndicator;

char *get_ufw_status();
void update_status(UfwIndicator *ufw);
void *start_periodic_check(void *ufw_ptr);
void launch_gufw(GtkWidget *widget, gpointer data);
void quit(GtkWidget *widget, gpointer data);
GtkWidget *build_menu(UfwIndicator *ufw);

int main(int argc, char **argv) {
    gtk_init(&argc, &argv);

    UfwIndicator *ufw = g_new0(UfwIndicator, 1);

    // Check if gufw exists
    if (system("which gufw > /dev/null") == 0) {
        ufw->active_icon_name = "gufw";
    } else {
        ufw->active_icon_name = "security-high-symbolic";
    }

    // Initialize AppIndicator
    ufw->indicator = app_indicator_new(ufw->active_icon_name, "security-high-symbolic", APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
    app_indicator_set_title(ufw->indicator, "Firewall Status");
    app_indicator_set_status(ufw->indicator, APP_INDICATOR_STATUS_ACTIVE);
    app_indicator_set_menu(ufw->indicator, GTK_MENU(build_menu(ufw)));

    ufw->last_status = g_strdup("");
    ufw->gc_tick = 0;
    ufw->status_tick = 0;

    // Periodically check UFW status
    update_status(ufw);

    // Start periodic check in a separate thread
    pthread_t status_check_thread;
    pthread_create(&status_check_thread, NULL, start_periodic_check, ufw);
    pthread_detach(status_check_thread);

    gtk_main();
    return 0;
}

GtkWidget *build_menu(UfwIndicator *ufw) {
    GtkWidget *menu = gtk_menu_new();

    // Check if gufw exists and add "Open Gufw" option
    if (system("which gufw > /dev/null") == 0) {
        GtkWidget *gufw_item = gtk_menu_item_new_with_label("Open Gufw");
        g_signal_connect(gufw_item, "activate", G_CALLBACK(launch_gufw), NULL);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), gufw_item);
    }

    // Add quit option
    GtkWidget *quit_item = gtk_menu_item_new_with_label("Quit");
    g_signal_connect(quit_item, "activate", G_CALLBACK(quit), NULL);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);

    gtk_widget_show_all(menu);
    return menu;
}

void launch_gufw(GtkWidget *widget, gpointer data) {
    system("gufw &");
}

void quit(GtkWidget *widget, gpointer data) {
    gtk_main_quit();
}

char *get_ufw_status() {
    FILE *fp;
    char path[1035];

    // Run command "ufw status" and get output
    fp = popen("ufw-status-check", "r");
    if (fp == NULL) {
        return g_strdup("unknown");
    }

    char *status = g_strdup("inactive");
    while (fgets(path, sizeof(path), fp) != NULL) {
        if (g_strrstr(g_ascii_strdown(path, -1), ": active")) {
            status = g_strdup("active");
            break;
        }
    }
    pclose(fp);
    return status;
}

void update_status(UfwIndicator *ufw) {
    char *status = get_ufw_status();

    if (g_strcmp0(ufw->last_status, status) != 0) {
        g_free(ufw->last_status);
        ufw->last_status = g_strdup(status);

        if (g_strcmp0(status, "active") == 0) {
            app_indicator_set_icon_full(ufw->indicator, ufw->active_icon_name, "UFW: Active");
        } else if (g_strcmp0(status, "inactive") == 0) {
            app_indicator_set_icon_full(ufw->indicator, "security-low-symbolic", "UFW: Inactive");
        } else {
            app_indicator_set_icon_full(ufw->indicator, "network-no-route-symbolic", "UFW: Status Unknown");
        }
    }

    g_free(status);
}

void *start_periodic_check(void *ufw_ptr) {
    UfwIndicator *ufw = (UfwIndicator *)ufw_ptr;

    while (1) {
        ufw->status_tick += 1;
        if (ufw->status_tick == 3) {
            g_idle_add((GSourceFunc)update_status, ufw);
            ufw->status_tick = 0;
        }

        ufw->gc_tick += 1;
        if (ufw->gc_tick == 60) {
            //g_collect();
            ufw->gc_tick = 0;
        }

        sleep(10);
    }
}
