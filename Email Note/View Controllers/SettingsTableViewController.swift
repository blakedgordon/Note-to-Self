//
//  SettingsTableViewController.swift
//  Email Note
//
//  Created by Blake Gordon on 12/11/18.
//  Copyright © 2018 Blake Gordon. All rights reserved.
//

import UIKit
import MessageUI
import StoreKit
import SVProgressHUD

class SettingsTableViewController: UITableViewController, UITextFieldDelegate, MFMailComposeViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    
    @IBOutlet weak var subjectTextField: UITextField!
    @IBOutlet weak var darkModeLabel: UILabel!
    @IBOutlet weak var darkModeSwitch: UISwitch!
    @IBOutlet weak var darkModeButtonOverlay: UIButton!
    @IBOutlet weak var darkIconLabel: UILabel!
    @IBOutlet weak var darkIconSwitch: UISwitch!
    @IBOutlet weak var darkIconButtonOverlay: UIButton!
    @IBOutlet weak var privacyLabel: UILabel!
    @IBOutlet weak var termsLabel: UILabel!
    @IBOutlet weak var contactLabel: UILabel!
    @IBOutlet weak var aboutLabel: UILabel!
    @IBOutlet weak var upgradeProButton: UIButton!
    @IBOutlet weak var remainingEmailsLabel: UILabel!
    
    weak var newEmailCell: NewEmailCell?
    
    var timer: Timer? = nil
    let numberOfTotalSections = 5
    
    var emails: [String] = User.emails
    
    var productsAvailable: [SKProduct]?
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        let rows = tableView.numberOfRows(inSection: 0)
        var emails: [String] = []
        var invalidEmail = false
        for row in 0..<rows {
            let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? EmailCell
            if let emailCell = cell, let email = emailCell.emailField.text {
                emails.append(email.trimmingCharacters(in: .whitespacesAndNewlines))
                if !User.isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    invalidEmail = true
                }
            }
        }
        
        if !invalidEmail {
            User.emails = emails
            if let subject = subjectTextField.text, subject != "" {
                SecureMail.subject = subject
            }
            view.endEditing(true)
            dismiss(animated: true)
        } else {
            var alertTitle = "Invalid Email"
            var alertMessage = "One or more of the emails you entered was invalid"
            if self.emails.count == 1 {
                alertTitle = "Enter Email"
                alertMessage = "Please enter a valid email address"
            }
            let alertAction = UIAlertAction(title: "Ok", style: .default)
            self.presentDarkAlert(title: alertTitle, message: alertMessage, actions: [alertAction], darkMode: User.darkMode)
        }
    }
    
    @IBAction func darkSwitched(_ sender: UISwitch) {
        view.endEditing(true)
        User.darkMode = sender.isOn
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5) {
            self.darkMode(on: User.darkMode)
            if let noteView = self.presentingViewController as? NoteViewController {
                noteView.darkMode(on: User.darkMode)
            }
        }
    }
    
    @IBAction func darkAppIconSwitched(_ sender: UISwitch) {
        view.endEditing(true)
        UIApplication.shared.setAlternateIconName(sender.isOn ? "Dark-AppIcon" : nil) { (error) in
            if error != nil {
                self.presentDarkAlert(title: "Uh Oh",
                                      message: "We had some trouble setting the app icon. Sorry about that! If this keeps happening, please contact support.",
                                      actions: [UIAlertAction(title: "Ok", style: .default)],
                                      darkMode: User.darkMode)
            }
        }
    }
    
    @IBAction func showUpgradeVC(_ sender: Any) {
        self.performSegue(withIdentifier: "showUpgrade", sender: sender)
    }
    
    @IBAction func upgradeToProPressed(_ sender: Any) {
        PurchaseView.upgrade(self, productsAvailable: productsAvailable)
    }
    
    func restorePurchasesPressed() {
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.clear)
        SVProgressHUD.show(withStatus: "Processing...")
        if productsAvailable?.count ?? 0 > 0 {
            NoteToSelfPro.store.restorePurchases()
        } else {
            self.presentDarkAlert(title: "Unavailable",
                                  message: "Looks like we've hit a snag and we can't seem to restore any purchases. Please contact support.",
                                  actions: [UIAlertAction(title: "Ok", style: .default)],
                                  darkMode: User.darkMode)
            SVProgressHUD.dismiss()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            if SVProgressHUD.isVisible() {
                SVProgressHUD.showError(withStatus: "Timeout Error")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "EmailCell", bundle: nil), forCellReuseIdentifier: "EmailCell")
        tableView.register(UINib(nibName: "NewEmailCell", bundle: nil), forCellReuseIdentifier: "NewEmailCell")
        
        subjectTextField.delegate = self
        navigationController?.presentationController?.delegate = self
        
        emails = User.emails
        
        NoteToSelfPro.validateReceipt()
        upgradeProButton.layer.cornerRadius = 5
        let upgradeProText = (NoteToSelfPro.proTrialExists ?? false) ? "Free Trial" : NoteToSelfPro.proPriceLabel
        upgradeProButton.setTitle(upgradeProText, for: .normal)
        upgradeProButton.updateConstraints()
        
        NotificationCenter.default.addObserver(self, selector: #selector(purchase),
                                               name: NSNotification.Name(rawValue: NoteToSelfPro.purchaseNotification), object: nil)
    }
    
    @objc func purchase(notification: NSNotification) {
        PurchaseView.purchase(self, notification: notification)

        self.tableView.reloadData()
        darkMode(on: User.darkMode)
        darkModeSwitch.isEnabled = User.purchasedPro
        darkModeSwitch.isOn = (User.purchasedPro) ? User.darkMode : false
        darkIconSwitch.isEnabled = User.purchasedPro
        let prevIconSwitch = darkIconSwitch.isOn
        darkIconSwitch.isOn = (User.purchasedPro) ? UIApplication.shared.alternateIconName != nil : false
        if prevIconSwitch != darkIconSwitch.isOn {
            darkAppIconSwitched(darkIconSwitch)
        }
        self.newEmailCell?.updateLabel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        subjectTextField.text = SecureMail.subject
        
        NoteToSelfPro.store.requestProducts { (_, products) in
            self.productsAvailable = products
        }
        
        self.newEmailCell?.updateLabel()
        darkModeSwitch.isEnabled = User.purchasedPro
        darkModeSwitch.isOn = (User.purchasedPro) ? User.darkMode : false
        darkIconSwitch.isEnabled = User.purchasedPro
        darkIconSwitch.isOn = (User.purchasedPro) ? UIApplication.shared.alternateIconName != nil : false
        if darkIconSwitch.isOn != (UIApplication.shared.alternateIconName != nil) {
            darkAppIconSwitched(darkIconSwitch)
        }
        if !User.purchasedPro {
            if Emails.remainingEmails > 0 {
                var emailText = (Emails.remainingEmails == 1) ? "email" : "emails"
                var remainingTime = (Emails.remainingTime == "00:00:00") ? "24 hours" : Emails.remainingTime
                remainingEmailsLabel.text = "Send \(Emails.remainingEmails) more \(emailText) for the next \(remainingTime)"
                if remainingTime != "24 hours" {
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        emailText = (Emails.remainingEmails == 1) ? "email" : "emails"
                        remainingTime = (Emails.remainingTime == "00:00:00") ? "24 hours" : Emails.remainingTime
                        self.remainingEmailsLabel.text = "Send \(Emails.remainingEmails) more \(emailText) for the next \(remainingTime)"
                    }
                }
            } else {
                remainingEmailsLabel.text = "Please wait \(Emails.remainingTime) to send another email"
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    self.remainingEmailsLabel.text = "Please wait \(Emails.remainingTime) to send another email"
                }
            }
        }
        
        darkMode(on: User.darkMode)
        if let noteView = self.presentingViewController as? NoteViewController {
            noteView.darkMode(on: User.darkMode)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return (User.emails == self.emails && SecureMail.subject == subjectTextField.text)
    }
    
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        let saveChangesAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        saveChangesAlert.addAction(UIAlertAction(title: "Save Changes", style: .default, handler: { (alert) in
            self.doneButtonPressed(alert)
        }))
        saveChangesAlert.addAction(UIAlertAction(title: "Discard Changes", style: .destructive, handler: { (alert) in
            self.view.endEditing(true)
            self.dismiss(animated: true)
        }))
        saveChangesAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(saveChangesAlert, animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    func darkMode(on: Bool) {
        self.view.backgroundColor = (on) ? .black : .groupTableViewBackground
        self.tableView.separatorColor = (on) ? .black : .lightGray
        self.navigationController?.navigationBar.barStyle = (on) ? .black : .default
        self.navigationController?.view.backgroundColor = (on) ? .black : .white
        self.navigationController?.navigationBar.titleTextAttributes =
            (on) ? [.foregroundColor: UIColor.white] : [.foregroundColor: UIColor.black]
        subjectTextField.textColor = (on) ? .white : .black
        darkModeLabel.textColor = (on) ? .white : .black
        darkIconLabel.textColor = (on) ? .white : .black
        remainingEmailsLabel.textColor = (on) ? .white : .black
        privacyLabel.textColor = (on) ? .white : .black
        termsLabel.textColor = (on) ? .white : .black
        contactLabel.textColor = (on) ? .white : .black
        aboutLabel.textColor = (on) ? .white : .black
        
        subjectTextField.keyboardAppearance = (on) ? .dark : .light
        
        tableView.separatorColor = (on) ? UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1) : UITableView().separatorColor        
        tableView.reloadData()
    }
    
    // FUNCTIONS BELOW RECIEVED FROM STACK OVERFLOW TO SEND AN EMAIL
    func sendEmailButtonTapped() {
        let mailComposeViewController = configuredMailComposeViewController()
        if MFMailComposeViewController.canSendMail() {
            self.present(mailComposeViewController, animated: true, completion: nil)
        }
    }
    
    func configuredMailComposeViewController() -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        // Extremely important to set the --mailComposeDelegate-- property, NOT the --delegate-- property
        mailComposerVC.mailComposeDelegate = self
        
        mailComposerVC.setToRecipients(["Note to Self Support <support@notetoselfapp.com>"])
        
        return mailComposerVC
    }
    
    // MARK: MFMailComposeViewControllerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        
    }
    // END
}
