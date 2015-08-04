//
//  CartViewController.m
//  MoltinSDK iOS Example
//
//  Created by Moltin on 19/06/15.
//  Copyright (c) 2015 Moltin. All rights reserved.
//

#import "CartViewController.h"
#import "AddressEntryViewController.h"
#import "CartListCell.h"

static NSString *CartCellIdentifier = @"MoltinCartCell";
static NSInteger ApplePaySheetId = 100;

// The maximum amount an Apple Pay transaction can be in the store's currency
// (for example, in the UK this is £20.00, so the value is 20.00)
static double ApplePayMaximumLimit = 20.00;

// The following constant is your Apple Pay merchant ID, as registered in the Apple Developer site
static NSString *ApplePayMerchantId = @"merchant.com.moltin.ApplePayExampleApp";

@interface CartViewController ()

@property (strong, nonatomic) NSNumber *cartPrice;
@property (strong, nonatomic) NSNumber *discountAmount;
@property (strong, nonatomic) NSDictionary *cartData;
@property (strong, nonatomic) NSArray *shippingMethods;

@end

@implementation CartViewController

+ (CartViewController *)sharedInstance {
    static CartViewController *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[CartViewController alloc] init];
    });
    
    return _sharedClient;
}

- (id)init{
    self = [super initWithNibName:@"CartView" bundle:nil];
    if (self) {
        
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadCart) name:kMoltinNotificationRefreshCart object:nil];
    
    self.view.backgroundColor = MOLTIN_DARK_BACKGROUND_COLOR;
    [self.tableView registerNib:[UINib nibWithNibName:@"CartListCell" bundle:nil] forCellReuseIdentifier:CartCellIdentifier];
    
    self.tableView.allowsMultipleSelectionDuringEditing = NO;

    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self loadCart];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMoltinNotificationRefreshCart object:nil];
}

- (void)loadCart{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Loading Cart";
    
    __weak CartViewController *weakSelf = self;
    [[Moltin sharedInstance].cart getContentsWithsuccess:^(NSDictionary *response) {
        _cartData = response;
        [weakSelf parseCartItems];
        
        NSLog(@"response = %@", response);
        
        weakSelf.cartPrice = [_cartData valueForKeyPath:@"result.totals.post_discount.raw.with_tax"];
        weakSelf.lbTotalPrice.text = [_cartData valueForKeyPath:@"result.totals.post_discount.formatted.with_tax"];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSDictionary *response, NSError *error) {
        NSLog(@"CART ERROR: %@\nWITH RESPONSE: %@", error, response);
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
}

- (void)parseCartItems
{
    NSDictionary *tmpCartItems = [self.cartData valueForKeyPath:@"result.contents"];
    if (tmpCartItems.count > 0) {
        self.cartItems = [tmpCartItems objectsForKeys:[tmpCartItems allKeys] notFoundMarker:[NSNull null]];
        self.lbNoProductsInCart.hidden = YES;
    }
    else{
        self.cartItems = nil;
        self.lbNoProductsInCart.hidden = NO;
    }
    
    self.btnCheckout.enabled = self.lbNoProductsInCart.hidden;
    [self.tableView reloadData];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)canUseApplePayForCart {
    // to use Apple Pay, the cart value must be under the limit, and the user must have an Apple Pay capable device.
    BOOL withinLimit = (self.cartPrice.doubleValue < ApplePayMaximumLimit && self.cartPrice.doubleValue > 0);
    BOOL supportedDevice = [PKPaymentAuthorizationViewController canMakePayments];
    
    if (supportedDevice && withinLimit) {
        // then yes.
        return YES;
    }
    
    return NO;
}

- (IBAction)btnCheckoutTap:(id)sender {
    // see if they can use Apple Pay - if so, present the Apple Pay option, if not, don't.
    if ([self canUseApplePayForCart]) {
        // present payment method choice sheet
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Select Payment Method"
                                                                 delegate:self
                                                        cancelButtonTitle:nil
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:@"Apple Pay", @"Credit/Debit Card", nil];
        actionSheet.tag = ApplePaySheetId;
        [actionSheet showInView:self.view];
        
    } else {
        // fallback to standard checkout flow
        [self presentStandardCheckoutFlow];
    }

}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0) {
        // Apple Pay
        [self checkoutWithApplePay];
    } else {
        // Normal checkout flow
        [self presentStandardCheckoutFlow];
    }
}

- (void)presentStandardCheckoutFlow {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"CheckoutStoryboard" bundle:nil];
    UIViewController *vc = [sb instantiateInitialViewController];
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [[MTSlideNavigationController sharedInstance] presentViewController:vc animated:YES completion:nil];
}

- (void)checkoutWithApplePay {
    // first, get shipping methods - then show the Apple pay view controller
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Loading Shipping Methods";
    
    [[Moltin sharedInstance].cart checkoutWithsuccess:^(NSDictionary *response) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        NSLog(@"response = %@", response);
        self.shippingMethods = [response valueForKeyPath:@"result.shipping.methods"];
        [self showApplePayViewController];
    } failure:^(NSDictionary *response, NSError *error) {
        NSLog(@"SHIPPING ERROR: %@", error);
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];

    
}

- (void)showApplePayViewController {
    PKPaymentRequest *request = [[PKPaymentRequest alloc] init];
    
    // IMPORTANT: Change this to your own merchant ID at the start of this file
    request.merchantIdentifier = ApplePayMerchantId;
    
    // Stripe supports all 3 Apply Pay networks
    request.supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa];
    request.merchantCapabilities = PKMerchantCapability3DS;
    
    // The example store is in the GB region, with pricing in GBP
    request.countryCode = @"GB";
    request.currencyCode = @"GBP";
    
    request.requiredBillingAddressFields = PKAddressFieldAll;
    request.requiredShippingAddressFields = PKAddressFieldAll;
    
    
    // Payment summary items must contain a total, any discount, and then the company name being paid
    
    NSDecimalNumber *subtotalAmount = [NSDecimalNumber decimalNumberWithDecimal:[self.cartPrice decimalValue]];
    PKPaymentSummaryItem *subtotal = [PKPaymentSummaryItem summaryItemWithLabel:@"Subtotal" amount:subtotalAmount];
    
    NSDecimalNumber *totalAmount = [NSDecimalNumber zero];
    totalAmount = [totalAmount decimalNumberByAdding:subtotalAmount];
    PKPaymentSummaryItem *total = [PKPaymentSummaryItem summaryItemWithLabel:@"Moltin" amount:totalAmount];
    
    request.paymentSummaryItems =  @[subtotal, total];
    
    // Now set up shipping methods too...
    NSMutableArray *shippingMethods = [NSMutableArray array];
    
    for (NSDictionary *method in self.shippingMethods) {
        NSDecimalNumber *shippingCost = [NSDecimalNumber decimalNumberWithDecimal:[[method valueForKeyPath:@"price.data.raw.with_tax"] decimalValue]];
        PKShippingMethod *shippingMethod = [PKShippingMethod summaryItemWithLabel:[method objectForKey:@"title"] amount:shippingCost];
        shippingMethod.detail = [method objectForKey:@"company"];
        shippingMethod.identifier = @"express";
        
        [shippingMethods addObject:shippingMethod];
    }
    
    request.shippingMethods = [NSArray arrayWithArray:shippingMethods];
    
    PKPaymentAuthorizationViewController *applePayViewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];
    
    applePayViewController.delegate = self;
    
    [self presentViewController:applePayViewController animated:YES completion:nil];
    
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus))completion {
    
    
    completion(PKPaymentAuthorizationStatusSuccess);
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingAddress:(ABRecordRef)address completion:(void (^)(PKPaymentAuthorizationStatus, NSArray *, NSArray *))completion {
    
    completion(PKPaymentAuthorizationStatusSuccess, nil, nil);
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod completion:(void (^)(PKPaymentAuthorizationStatus, NSArray *))completion {
    
    completion(PKPaymentAuthorizationStatusSuccess, nil);
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - TableView
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.cartItems.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    CartListCell *cell = [tableView dequeueReusableCellWithIdentifier:CartCellIdentifier];
    if (cell == nil) {
        
        cell = [[CartListCell alloc] init];
    }
    
    NSDictionary *cartItem = [self.cartItems objectAtIndex:indexPath.row];
    [cell configureWithCartItemDict:cartItem];
    cell.delegate = self;
    
    return cell;
}

-(void)updateCartWithProductId:(NSString *)productId andQuantity:(NSNumber *)quantity
{
    __weak CartViewController *weakSelf = self;
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Updating Cart";
    
    // if quantity is zero, the Moltin API automagically knows to remove the item from the cart
    // update to new quantity value...
    [[Moltin sharedInstance].cart updateItemWithId:productId parameters:@{@"quantity" : quantity}
                                           success:^(NSDictionary *response){
                                               [MBProgressHUD hideHUDForView:weakSelf.view animated:YES];
                                               [weakSelf loadCart];
                                           }
                                           failure:^(NSDictionary *response, NSError *error) {
                                               [MBProgressHUD hideHUDForView:weakSelf.view animated:YES];
                                               NSLog(@"ERROR CART UPDATE: %@", error);
                                               [weakSelf loadCart];
                                           }];
    
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return YES if you want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // remove item at indexPath.row from the cart...
        NSString *productIdString = [[self.cartItems objectAtIndex:indexPath.row] objectForKey:@"id"];
        
        // weakSelf allows us to refer to self safely inside of the completion handler blocks.
        __weak CartViewController *weakSelf = self;
        
        // show some loading UI...
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Updating Cart";
        
        // now remove it...
        [[Moltin sharedInstance].cart removeItemWithId:productIdString success:^(NSDictionary *response) {
            // hide loading dialog and refresh...
            [MBProgressHUD hideHUDForView:weakSelf.view animated:YES];
            [weakSelf loadCart];
        } failure:^(NSDictionary *response, NSError *error) {
            // log error, hide loading dialog, refresh...
            [MBProgressHUD hideHUDForView:weakSelf.view animated:YES];
            NSLog(@"ERROR CART UPDATE: %@", error);
            [weakSelf loadCart];
        }];
        
    }
}

@end
