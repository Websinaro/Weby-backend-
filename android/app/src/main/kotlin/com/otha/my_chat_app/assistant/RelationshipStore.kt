package com.otha.my_chat_app.assistant

import android.content.Context
import org.json.JSONObject

/**
 * Stores "who is my bro / mom / dad" mappings in a private SharedPreferences
 * file - device-only, never synchronized to the Weby backend (the backend
 * has no model for this at all, by design; see spec section 27).
 */
object RelationshipStore {

    private const val PREFS_NAME = "weby_relationships"
    private const val KEY_MAP = "relationship_map" // JSON: { "bro": {"contactId","name","phoneNumber"} }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getAll(context: Context): Map<String, ContactsBridge.Contact> {
        val raw = prefs(context).getString(KEY_MAP, null) ?: return emptyMap()
        val json = JSONObject(raw)
        val result = mutableMapOf<String, ContactsBridge.Contact>()
        json.keys().forEach { relationship ->
            val entry = json.getJSONObject(relationship)
            result[relationship] = ContactsBridge.Contact(
                id = entry.getString("contactId"),
                name = entry.getString("name"),
                phoneNumber = entry.optString("phoneNumber", null),
            )
        }
        return result
    }

    fun set(context: Context, relationship: String, contact: ContactsBridge.Contact) {
        val current = JSONObject(prefs(context).getString(KEY_MAP, null) ?: "{}")
        val entry = JSONObject().apply {
            put("contactId", contact.id)
            put("name", contact.name)
            put("phoneNumber", contact.phoneNumber ?: JSONObject.NULL)
        }
        current.put(relationship.lowercase(), entry)
        prefs(context).edit().putString(KEY_MAP, current.toString()).apply()
    }

    fun remove(context: Context, relationship: String) {
        val current = JSONObject(prefs(context).getString(KEY_MAP, null) ?: "{}")
        current.remove(relationship.lowercase())
        prefs(context).edit().putString(KEY_MAP, current.toString()).apply()
    }

    fun resolve(context: Context, relationship: String): ContactsBridge.Contact? {
        return getAll(context)[relationship.lowercase().trim()]
    }
}
