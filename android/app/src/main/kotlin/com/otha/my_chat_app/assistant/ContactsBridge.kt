package com.otha.my_chat_app.assistant

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import androidx.core.content.ContextCompat

/**
 * Reads the device contact list LOCALLY ONLY. Nothing here ever leaves
 * the device - there is deliberately no network call in this file, and
 * no contact data is ever included in a request to the Weby backend.
 */
object ContactsBridge {

    data class Contact(val id: String, val name: String, val phoneNumber: String?)

    private fun hasContactsPermission(context: Context) =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    fun listContacts(context: Context): List<Contact> {
        if (!hasContactsPermission(context)) return emptyList()

        val contacts = mutableListOf<Contact>()
        val resolver = context.contentResolver
        val cursor = resolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            null, null,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        )

        cursor?.use {
            val idIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (it.moveToNext()) {
                val id = it.getString(idIdx) ?: continue
                val name = it.getString(nameIdx) ?: continue
                val number = it.getString(numberIdx)
                contacts.add(Contact(id, name, number))
            }
        }

        return contacts.distinctBy { it.id }
    }

    /**
     * Places a call. Uses ACTION_CALL (direct dial) if CALL_PHONE has
     * been granted; otherwise falls back to ACTION_DIAL, which opens the
     * dialer pre-filled with the number and requires no permission at all
     * - so calling always degrades gracefully rather than failing silently.
     */
    fun callNumber(context: Context, phoneNumber: String): CallResult {
        val uri = Uri.parse("tel:${Uri.encode(phoneNumber)}")
        val hasCallPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED

        return try {
            val action = if (hasCallPermission) Intent.ACTION_CALL else Intent.ACTION_DIAL
            val intent = Intent(action, uri).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            context.startActivity(intent)
            if (hasCallPermission) CallResult.Called else CallResult.OpenedDialer
        } catch (e: SecurityException) {
            CallResult.PermissionDenied
        }
    }

    sealed class CallResult {
        object Called : CallResult()
        object OpenedDialer : CallResult()
        object PermissionDenied : CallResult()
    }
}
