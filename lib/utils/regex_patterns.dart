/// Regex patterns for parsing Indian bank transactional SMS
/// Supports: HDFC, ICICI, SBI, AXIS, KOTAK, YES BANK, IndusInd

class IndianBankRegexPatterns {
  // Amount regex patterns (supports ₹ and INR formats)
  static const String amountPattern = r'(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)';
  
  // Merchant/Vendor name patterns
  static const String merchantPattern = r'(?:at|to|from|@)\s+([A-Za-z0-9\s\-\.\,&\']*)(?:\s+(?:on|via|for|INR|RS|₹)|\s*$)';
  
  // Transaction time patterns
  static const String timePattern = r'(?:on|at|time)\s+(\d{1,2}\/\d{1,2}\/\d{2,4}\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*(?:AM|PM|am|pm))?|\d{1,2}:\d{2}(?::\d{2})?(?:\s*(?:AM|PM|am|pm))?)';

  // VPA (Virtual Payment Address) pattern for UPI
  static const String vpaPattern = r'([a-zA-Z0-9\.\-_]+@[a-zA-Z]+)';

  // Transaction reference number
  static const String refPattern = r'(?:Ref|Reference|UTR|TXN)[\s#:]*([A-Z0-9]+)';

  // Bank-specific patterns

  /// HDFC Bank Pattern
  /// Example: "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45 IST"
  static const String hdfcPattern = 
    r'(?:debited|credited)\s+with\s+(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:at|from)\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+(?:on|at)\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// ICICI Bank Pattern
  /// Example: "Dear Customer, Your a/c XXXXXXXX7890 was debited for INR 250.00 at Amazon on 21/06/2024 13:45:30 IST"
  static const String iciciBankPattern = 
    r'(?:debited|credited)\s+(?:for|with)\s+(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s+at\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+(?:on|at)\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}(?::\d{2})?)';

  /// SBI Bank Pattern
  /// Example: "INR 300.00 debited towards Flipkart on 21/06/2024 13:45"
  static const String sbiPattern = 
    r'(?:INR|₹|Rs)\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:debited|credited)\s+(?:towards|at|from)\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// AXIS Bank Pattern
  /// Example: "Your account XXXXXXXX7890 was debited by INR 150.00 at BigBasket on 21/06/2024 13:45 IST"
  static const String axisPattern = 
    r'(?:debited|credited)\s+by\s+(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s+at\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// KOTAK Bank Pattern
  /// Example: "Dear Customer, INR 200.00 debited from your account ending XXXX7890 at Uber on 21/06/2024 13:45"
  static const String kotakPattern = 
    r'(?:INR|₹|Rs)\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:debited|credited)\s+(?:from|at)\s+(?:your\s+account\s+)?(?:ending\s+)?[A-Za-z0-9\s]*?\s+at\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// YES BANK Pattern
  /// Example: "Alert: INR 100.00 debited from account ending 7890 at Zomato on 21/06/2024 13:45"
  static const String yesBankPattern = 
    r'(?:INR|₹|Rs)\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:debited|credited)\s+from\s+(?:account\s+ending\s+)?[A-Za-z0-9\s]*?\s+at\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// IndusInd Bank Pattern
  /// Example: "Your account ending 7890 was debited INR 175.00 at OYO Hotels on 21/06/2024 13:45"
  static const String indusindPattern = 
    r'(?:debited|credited)\s+(?:INR|₹|Rs)\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+at\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// Generic UPI Transaction Pattern
  /// For catching UPI-based transactions
  static const String upiPattern = 
    r'(?:UPI|VPA)\s+(?:to|from)\s+([A-Za-z0-9\.\-_]+@[a-zA-Z]+)\s+.*?(?:INR|₹|Rs)\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:at|on)?\s+([A-Za-z0-9\s\-\.\,&\']+?)?\s*(?:on|at)?\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})';

  /// Get all bank patterns in order of priority
  static final List<String> allPatterns = [
    hdfcPattern,
    iciciBankPattern,
    sbiPattern,
    axisPattern,
    kotakPattern,
    yesBankPattern,
    indusindPattern,
    upiPattern,
  ];

  /// Keywords to identify transactional SMS
  static final List<String> transactionKeywords = [
    'debited',
    'credited',
    'debit',
    'credit',
    'INR',
    'UPI',
    'transaction',
    'payment',
    'transferred',
    'received',
    '₹',
    'withdrawn',
  ];

  /// Merchants to exclude (ATM, Balance Check, etc.)
  static final List<String> excludedMerchants = [
    'ATM',
    'balance',
    'mini statement',
    'branch',
    'information',
    'charges',
    'interest',
  ];
}
