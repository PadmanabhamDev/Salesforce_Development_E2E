public class StaticVsNonStatic {
    public static final Decimal PI = 3.14;
    
    public static void accData(){
       	List<Account> acc = [Select Id From Account Limit 1];
        System.debug(acc[0]);
    }
    
    public static void resultIf(Integer marks){
        if (marks >= 90) {
            System.debug('Grade A');
        } else if (marks >= 75) {
            System.debug('Grade B');
        } else if (marks >= 60) {
            System.debug('Grade C');
        } else {
            System.debug('Grade D');
        }
    }
    
    public static void switchTest(String accountType){
        switch on accountType {
            
            when 'Customer' {
                System.debug('Customer Account');
            }
            when 'Partner' {
                System.debug('Partner Account');
            }
            when 'Vendor' {
                System.debug('Vendor Account');
            }
            when else {
                System.debug('Unknown Account Type');
            }
        }
    }
}