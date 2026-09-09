/*
 * cob_sqlite.c - High-Performance C Bridge between GnuCOBOL and SQLite3
 * 
 * Provides type-safe functions for executing SQL, stepping through cursors,
 * and converting space-padded COBOL fields into null-terminated C strings.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sqlite3.h>

/* Safely convert a space-padded COBOL string into a null-terminated C string */
static void cob_to_c_str(const char *src, char *dst, size_t dst_capacity, int max_src_len) {
    if (dst == NULL || dst_capacity == 0) {
        return;
    }
    dst[0] = '\0';
    if (src == NULL || max_src_len <= 0) {
        return;
    }
    int len = 0;
    int limit = max_src_len;
    if ((size_t)limit >= dst_capacity) {
        limit = (int)dst_capacity - 1;
    }
    while (len < limit && src[len] != '\0') {
        len++;
    }
    while (len > 0 && (src[len - 1] == ' ' || src[len - 1] == '\r' || src[len - 1] == '\n' || src[len - 1] == '\t')) {
        len--;
    }
    if (len > 0) {
        memcpy(dst, src, (size_t)len);
    }
    dst[len] = '\0';
}

/* Open or create an SQLite database */
int cob_sqlite_open(const char *filename, sqlite3 **db_out, int32_t *status_out) {
    if (db_out == NULL) {
        if (status_out != NULL) {
            *status_out = SQLITE_MISUSE;
        }
        return SQLITE_MISUSE;
    }
    if (filename == NULL) {
        *db_out = NULL;
        if (status_out != NULL) {
            *status_out = SQLITE_MISUSE;
        }
        return SQLITE_MISUSE;
    }
    char c_file[1024];
    cob_to_c_str(filename, c_file, sizeof(c_file), 512);
    int rc = sqlite3_open(c_file, db_out);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "[cob_sqlite_open error %d]: %s\nFilename: '%s'\n",
                rc, (*db_out != NULL) ? sqlite3_errmsg(*db_out) : "Failed to allocate SQLite handle", c_file);
    }
    if (status_out != NULL) {
        *status_out = rc;
    }
    return rc;
}

/* Execute immediate DDL or DML statement */
int cob_sqlite_exec(sqlite3 **db_in, const char *sql, int32_t *status_out) {
    if (db_in == NULL || *db_in == NULL || sql == NULL) {
        if (status_out != NULL) {
            *status_out = SQLITE_MISUSE;
        }
        return SQLITE_MISUSE;
    }
    char c_sql[4096];
    char *err_msg = NULL;
    cob_to_c_str(sql, c_sql, sizeof(c_sql), 512);
    int rc = sqlite3_exec(*db_in, c_sql, NULL, NULL, &err_msg);
    if (err_msg != NULL) {
        fprintf(stderr, "[cob_sqlite_exec error %d]: %s\nQuery: '%s'\n", rc, err_msg, c_sql);
        sqlite3_free(err_msg);
    }
    if (status_out != NULL) {
        *status_out = rc;
    }
    return rc;
}

/* Prepare a SQL query for cursor execution */
int cob_sqlite_prepare(sqlite3 **db_in, const char *sql, sqlite3_stmt **stmt_out, int32_t *status_out) {
    if (db_in == NULL || *db_in == NULL || sql == NULL || stmt_out == NULL) {
        if (stmt_out != NULL) {
            *stmt_out = NULL;
        }
        if (status_out != NULL) {
            *status_out = SQLITE_MISUSE;
        }
        return SQLITE_MISUSE;
    }
    char c_sql[4096];
    cob_to_c_str(sql, c_sql, sizeof(c_sql), 512);
    int rc = sqlite3_prepare_v2(*db_in, c_sql, -1, stmt_out, NULL);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "[cob_sqlite_prepare error %d]: %s\nQuery: '%s'\n", rc, sqlite3_errmsg(*db_in), c_sql);
        *stmt_out = NULL;
    }
    if (status_out != NULL) {
        *status_out = rc;
    }
    return rc;
}

/* Step to next row in cursor */
int cob_sqlite_step(sqlite3_stmt **stmt_in, int32_t *status_out) {
    if (stmt_in == NULL || *stmt_in == NULL) {
        if (status_out != NULL) {
            *status_out = SQLITE_MISUSE;
        }
        return SQLITE_MISUSE;
    }
    int rc = sqlite3_step(*stmt_in);
    if (status_out != NULL) {
        *status_out = rc;
    }
    return rc;
}

/* Retrieve 32-bit integer column value */
int cob_sqlite_get_int(sqlite3_stmt **stmt_in, int col_idx, int32_t *int_out) {
    if (int_out == NULL) {
        return SQLITE_MISUSE;
    }
    int32_t val = 0;
    if (stmt_in != NULL && *stmt_in != NULL) {
        val = (int32_t)sqlite3_column_int(*stmt_in, col_idx);
    }
    memcpy(int_out, &val, sizeof(int32_t));
    return SQLITE_OK;
}

/* Retrieve 64-bit floating point (double) column value */
int cob_sqlite_get_double(sqlite3_stmt **stmt_in, int col_idx, double *dbl_out) {
    if (dbl_out == NULL) {
        return SQLITE_MISUSE;
    }
    double val = 0.0;
    if (stmt_in != NULL && *stmt_in != NULL) {
        val = sqlite3_column_double(*stmt_in, col_idx);
    }
    memcpy(dbl_out, &val, sizeof(double));
    return SQLITE_OK;
}

/* Retrieve text column value and space-pad to COBOL fixed-width buffer */
int cob_sqlite_get_text(sqlite3_stmt **stmt_in, int col_idx, char *dest, int max_len) {
    if (dest == NULL || max_len <= 0) {
        return SQLITE_MISUSE;
    }
    int len = 0;
    if (stmt_in != NULL && *stmt_in != NULL) {
        const unsigned char *text = sqlite3_column_text(*stmt_in, col_idx);
        if (text != NULL) {
            len = sqlite3_column_bytes(*stmt_in, col_idx);
            if (len > max_len) {
                len = max_len;
            }
            memcpy(dest, text, (size_t)len);
        }
    }
    if (len < max_len) {
        memset(dest + len, ' ', (size_t)(max_len - len));
    }
    return SQLITE_OK;
}

/* Finalize prepared statement */
int cob_sqlite_finalize(sqlite3_stmt **stmt_in, int32_t *status_out) {
    int rc = SQLITE_OK;
    if (stmt_in != NULL && *stmt_in != NULL) {
        rc = sqlite3_finalize(*stmt_in);
        *stmt_in = NULL;
    }
    if (status_out != NULL) {
        *status_out = rc;
    }
    return rc;
}

/* Close SQLite database connection */
int cob_sqlite_close(sqlite3 **db_in, int32_t *status_out) {
    int rc = SQLITE_OK;
    if (db_in != NULL && *db_in != NULL) {
        rc = sqlite3_close_v2(*db_in);
        *db_in = NULL;
    }
    if (status_out != NULL) {
        *status_out = rc;
    }
    return rc;
}

