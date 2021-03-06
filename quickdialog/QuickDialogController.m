//                                
// Copyright 2011 ESCOZ Inc  - http://escoz.com
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this 
// file except in compliance with the License. You may obtain a copy of the License at 
// 
// http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF 
// ANY KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

static const CGFloat kKeyboardAnimationDuration = 0.3;

@interface QuickDialogController ()

@property (nonatomic, assign) BOOL keyboardIsShown;
@property (nonatomic, assign) CGFloat originalHeight;
@property (nonatomic, assign) CGFloat sizedHeight;

+ (Class)controllerClassForRoot:(QRootElement *)root;
- (CGFloat)accessoryHeight;

@end


@implementation QuickDialogController {
    BOOL _keyboardVisible;
    BOOL _viewOnScreen;
    BOOL _resizeWhenKeyboardPresented;
}

@synthesize root = _root;
@synthesize willDisappearCallback = _willDisappearCallback;
@synthesize quickDialogTableView = _quickDialogTableView;
@synthesize resizeWhenKeyboardPresented = _resizeWhenKeyboardPresented;
@synthesize keyboardIsShown = _keyboardIsShown;
@synthesize originalHeight = originalHeight_;
@synthesize sizedHeight = sizedHeight_;


+ (QuickDialogController *)buildControllerWithClass:(Class)controllerClass root:(QRootElement *)root {
    controllerClass = controllerClass==nil? [QuickDialogController class] : controllerClass;
    return [((QuickDialogController *)[controllerClass alloc]) initWithRoot:root];
}

+ (QuickDialogController *)controllerForRoot:(QRootElement *)root {
    Class controllerClass = [self controllerClassForRoot:root];
    return [((QuickDialogController *)[controllerClass alloc]) initWithRoot:root];
}


+ (Class)controllerClassForRoot:(QRootElement *)root {
    Class controllerClass = nil;
    if (root.controllerName!=NULL){
        controllerClass = NSClassFromString(root.controllerName);
    } else {
        controllerClass = [self class];
    }
    return controllerClass;
}

+ (UINavigationController*)controllerWithNavigationForRoot:(QRootElement *)root {
    return [[UINavigationController alloc] initWithRootViewController:[QuickDialogController
                                                                       buildControllerWithClass:[self controllerClassForRoot:root]
                                                                       root:root]];
}

- (void)loadView {
    [super loadView];
    self.quickDialogTableView = [[QuickDialogTableView alloc] initWithController:self];
    self.view = self.quickDialogTableView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];

	self.sizedHeight = 0;
}

- (QuickDialogController *)initWithRoot:(QRootElement *)rootElement {
    self = [super init];
    if (self) {
        self.root = rootElement;
        self.resizeWhenKeyboardPresented =YES;
    }
    return self;
}

- (void)setRoot:(QRootElement *)root {
    _root = root;
    self.quickDialogTableView.root = root;
    self.title = _root.title;
    self.navigationItem.title = _root.title;
}

- (void)viewWillAppear:(BOOL)animated {
    _viewOnScreen = YES;
    [self.quickDialogTableView viewWillAppear];
    [super viewWillAppear:animated];
    if (_root!=nil)
        self.title = _root.title;

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(keyboardWillShow:) 
												 name:UIKeyboardWillShowNotification 
											   object:self.view.window];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(keyboardWillHide:) 
												 name:UIKeyboardWillHideNotification 
											   object:self.view.window];
	self.keyboardIsShown = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    _viewOnScreen = NO;
    [super viewWillDisappear:animated];
    if (_willDisappearCallback!=nil){
        _willDisappearCallback();
    }
	[self.view endEditing:YES];

	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:UIKeyboardWillShowNotification 
												  object:nil]; 
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:UIKeyboardWillHideNotification 
												  object:nil];	
}

- (void)popToPreviousRootElement {
    if (self.navigationController!=nil){
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)displayViewController:(UIViewController *)newController {
    if (self.navigationController != nil ){
        [self.navigationController pushViewController:newController animated:YES];
    } else {
        [self presentModalViewController:newController animated:YES];
    }
}

- (void)displayViewControllerForRoot:(QRootElement *)root {
    QuickDialogController *newController = [self controllerForRoot: root];
    [self displayViewController:newController];
}


- (QuickDialogController *)controllerForRoot:(QRootElement *)root {
    Class controllerClass = [[self class] controllerClassForRoot:root];
    return [QuickDialogController buildControllerWithClass:controllerClass root:root];
}

- (void)keyboardWillHide:(NSNotification *)n {
	NSDictionary *userInfo = [n userInfo];

	// Get the size of the keyboard
	CGRect keyboardRect = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	keyboardRect = [self.view convertRect:keyboardRect fromView:nil];

	// Resize the scrollview
	CGRect viewFrame = self.quickDialogTableView.frame;
	viewFrame.size.height = self.originalHeight;

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:kKeyboardAnimationDuration];
	[self.quickDialogTableView setFrame:viewFrame];
	[UIView commitAnimations];

	self.keyboardIsShown = NO;
}

- (void)keyboardWillShow:(NSNotification *)n {
	// Ensure that we do not do the frame size adjustment on the UIScrollView if the keyboard is already shown.
	// This can happen if the user, after fixing editing a UITextField, scrolls the resized UIScrollView to another UITextField and attempts to edit the next UITextField.
	// If we were to resize the UIScrollView again, it would be disastrous.  NOTE: The keyboard notification will fire even when the keyboard is already shown.
	if (self.keyboardIsShown) return;

	NSDictionary *userInfo = [n userInfo];

	// Get the size of the keyboard
	CGRect keyboardRect = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	keyboardRect = [self.view convertRect:keyboardRect fromView:nil];
	CGSize keyboardSize = keyboardRect.size;

	CGRect viewFrame = self.quickDialogTableView.frame;
	self.originalHeight = viewFrame.size.height;

	if (self.sizedHeight) {
		viewFrame.size.height = self.sizedHeight;
	} else {
		viewFrame.size.height -= (keyboardSize.height - self.tabBarController.tabBar.frame.size.height - self.accessoryHeight);
		self.sizedHeight = viewFrame.size.height;
	}

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationBeginsFromCurrentState:YES];

	[UIView setAnimationDuration:kKeyboardAnimationDuration];
	[self.quickDialogTableView setFrame:viewFrame];
	[UIView commitAnimations];

	self.keyboardIsShown = YES;
}

- (CGFloat)accessoryHeight {
	CGFloat accessoryHeight = 0;
	for (QEntryTableViewCell *cell in self.quickDialogTableView.visibleCells) {
		if ([cell respondsToSelector:@selector(textField)] && cell.textField.isFirstResponder && cell.textField.inputAccessoryView) {
			accessoryHeight = cell.textField.inputAccessoryView.frame.size.height;
			break;
		}
	}

	return accessoryHeight;
}


@end
