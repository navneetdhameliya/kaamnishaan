"""Words on the customer PDF and in the messages that carry the report link, in the 5 languages.

Hindi, Gujarati, Spanish and French still need a native speaker's review (docs/decisions.md, open items).
SMS and WhatsApp texts end with a STOP line (A39). In India each SMS text must also be registered as a
DLT template before MSG91 will send it.
"""

LABELS: dict[str, dict[str, str]] = {
    "en": {
        "title": "Service report", "customer": "Customer", "address": "Address", "job": "Job",
        "technician": "Technician", "approved_by": "Approved by", "date": "Date", "summary": "Summary",
        "work_done": "Work done", "before_after": "Before and after", "before": "Before", "after": "After",
        "photos": "Photos", "checklist": "Checklist", "pass": "Pass", "fail": "Fail", "yes": "Yes", "no": "No", "advice": "Advice",
        "locked": "Photos were locked on {date} and can't be changed. Verified by KaamNishaan.",
        "page": "Page {n}",
        "sms": "{company}: your service report {number} is ready. View it here: {link}",
        "stop": "Reply STOP to opt out.",
        "review_sms": "{company}: report {number} is ready. Rate the job here: {link}",
        "review_email": "How did we do? Rate the job in one tap on the report page.",
        "review_reminder": "{company}: how did we do on {job}? It takes one tap: {link}",
        "day5_sms": "{company}: how was {job}? Rate it in one tap: {link}",
        "email_subject": "Your service report {number} from {company}",
        "email_body": "Hello {name},\n\n{company} has finished the work: {job}.\nYour report with photos is here: {link}\n"
        "The link works until {expires}.",
        "new_link_subject": "A customer asked for a new report link",
        "problem_subject": "A customer reported a problem with report {number}",
    },
    "hi": {
        "title": "सर्विस रिपोर्ट", "customer": "ग्राहक", "address": "पता", "job": "काम",
        "technician": "टेक्नीशियन", "approved_by": "मंज़ूरी दी", "date": "तारीख", "summary": "सारांश",
        "work_done": "किया गया काम", "before_after": "पहले और बाद में", "before": "पहले", "after": "बाद में",
        "photos": "फोटो", "checklist": "चेकलिस्ट", "pass": "ठीक", "fail": "ठीक नहीं", "yes": "हाँ", "no": "नहीं", "advice": "सलाह",
        "locked": "फोटो {date} को लॉक की गईं और बदली नहीं जा सकतीं। KaamNishaan द्वारा सत्यापित।",
        "page": "पेज {n}",
        "sms": "{company}: आपकी सर्विस रिपोर्ट {number} तैयार है। यहां देखें: {link}",
        "stop": "बंद करने के लिए STOP भेजें।",
        "review_sms": "{company}: आपकी सर्विस रिपोर्ट {number} तैयार है। कृपया काम को यहां रेट करें: {link}",
        "review_email": "हमारा काम कैसा रहा? रिपोर्ट पेज पर एक टैप में रेट करें।",
        "review_reminder": "{company}: {job} का काम कैसा रहा? एक टैप में बताएं: {link}",
        "day5_sms": "{company}: {job} का काम कैसा लगा? एक टैप में रेटिंग दें: {link}",
        "email_subject": "{company} से आपकी सर्विस रिपोर्ट {number}",
        "email_body": "नमस्ते {name},\n\n{company} ने काम पूरा कर लिया है: {job}.\nफोटो के साथ आपकी रिपोर्ट यहां है: {link}\n"
        "यह लिंक {expires} तक चलेगा।",
    },
    "gu": {
        "title": "સર્વિસ રિપોર્ટ", "customer": "ગ્રાહક", "address": "સરનામું", "job": "કામ",
        "technician": "ટેક્નિશિયન", "approved_by": "મંજૂરી આપનાર", "date": "તારીખ", "summary": "સારાંશ",
        "work_done": "કરેલું કામ", "before_after": "પહેલાં અને પછી", "before": "પહેલાં", "after": "પછી",
        "photos": "ફોટા", "checklist": "ચેકલિસ્ટ", "pass": "બરાબર", "fail": "બરાબર નથી", "yes": "હા", "no": "ના", "advice": "સલાહ",
        "locked": "ફોટા {date} ના રોજ લૉક થયા અને બદલી શકાતા નથી. KaamNishaan દ્વારા ચકાસાયેલ.",
        "page": "પેજ {n}",
        "sms": "{company}: તમારો સર્વિસ રિપોર્ટ {number} તૈયાર છે. અહીં જુઓ: {link}",
        "stop": "બંધ કરવા STOP મોકલો.",
        "review_sms": "{company}: તમારો સર્વિસ રિપોર્ટ {number} તૈયાર છે. કૃપા કરી કામને અહીં રેટ કરો: {link}",
        "review_email": "અમારું કામ કેવું રહ્યું? રિપોર્ટ પેજ પર એક ટેપમાં રેટ કરો.",
        "review_reminder": "{company}: {job} નું કામ કેવું રહ્યું? એક ટેપમાં કહો: {link}",
        "day5_sms": "{company}: {job}નું કામ કેવું લાગ્યું? એક ટૅપમાં રેટિંગ આપો: {link}",
        "email_subject": "{company} તરફથી તમારો સર્વિસ રિપોર્ટ {number}",
        "email_body": "નમસ્તે {name},\n\n{company} એ કામ પૂરું કર્યું છે: {job}.\nફોટા સાથે તમારો રિપોર્ટ અહીં છે: {link}\n"
        "આ લિંક {expires} સુધી ચાલશે.",
    },
    "es": {
        "title": "Informe de servicio", "customer": "Cliente", "address": "Dirección", "job": "Trabajo",
        "technician": "Técnico", "approved_by": "Aprobado por", "date": "Fecha", "summary": "Resumen",
        "work_done": "Trabajo realizado", "before_after": "Antes y después", "before": "Antes",
        "after": "Después", "photos": "Fotos", "checklist": "Lista de control", "pass": "Correcto",
        "fail": "Incorrecto", "yes": "Sí", "no": "No", "advice": "Recomendaciones",
        "locked": "Las fotos se bloquearon el {date} y no se pueden cambiar. Verificado por KaamNishaan.",
        "page": "Página {n}",
        "sms": "{company}: su informe de servicio {number} está listo. Véalo aquí: {link}",
        "stop": "Responda STOP para no recibir más mensajes.",
        "review_sms": "{company}: su informe de servicio {number} está listo. Valore el trabajo aquí: {link}",
        "review_email": "¿Qué tal lo hicimos? Valore el trabajo con un toque en la página del informe.",
        "review_reminder": "{company}: ¿qué tal fue {job}? Solo un toque: {link}",
        "day5_sms": "{company}: nos encantaría saber qué tal fue {job}. Valóralo con un toque: {link}",
        "email_subject": "Su informe de servicio {number} de {company}",
        "email_body": "Hola {name}:\n\n{company} ha terminado el trabajo: {job}.\nSu informe con fotos está aquí: {link}\n"
        "El enlace funciona hasta el {expires}.",
    },
    "fr": {
        "title": "Rapport d'intervention", "customer": "Client", "address": "Adresse", "job": "Intervention",
        "technician": "Technicien", "approved_by": "Approuvé par", "date": "Date", "summary": "Résumé",
        "work_done": "Travaux réalisés", "before_after": "Avant et après", "before": "Avant", "after": "Après",
        "photos": "Photos", "checklist": "Liste de contrôle", "pass": "Conforme", "fail": "Non conforme",
        "yes": "Oui", "no": "Non", "advice": "Conseils",
        "locked": "Les photos ont été verrouillées le {date} et ne peuvent plus être modifiées. "
        "Vérifié par KaamNishaan.",
        "page": "Page {n}",
        "sms": "{company} : votre rapport d'intervention {number} est prêt. Consultez-le ici : {link}",
        "stop": "Répondez STOP pour ne plus recevoir de messages.",
        "review_sms": "{company} : votre rapport d’intervention {number} est prêt. Notez le travail ici : {link}",
        "review_email": "Comment s’est passée l’intervention ? Notez-la en un geste sur la page du rapport.",
        "review_reminder": "{company} : comment s’est passé {job} ? Un seul geste : {link}",
        "day5_sms": "{company} : comment s’est passé {job} ? Notez-le en un geste : {link}",
        "email_subject": "Votre rapport d'intervention {number} de {company}",
        "email_body": "Bonjour {name},\n\n{company} a terminé l'intervention : {job}.\n"
        "Votre rapport avec photos est ici : {link}\nLe lien fonctionne jusqu'au {expires}.",
    },
}  # fmt: skip

MONTHS_EN = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")


def label(lang: str, key: str, **kw: object) -> str:
    text = LABELS.get(lang, LABELS["en"]).get(key) or LABELS["en"][key]
    return text.format(**kw) if kw else text


def fmt_date(d, lang: str) -> str:
    """16 Nov 2026 in English; 16/11/2026 in the other languages."""
    if d is None:
        return ""
    return f"{d.day} {MONTHS_EN[d.month - 1]} {d.year}" if lang == "en" else d.strftime("%d/%m/%Y")
