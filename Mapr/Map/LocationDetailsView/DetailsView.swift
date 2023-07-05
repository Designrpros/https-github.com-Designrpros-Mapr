import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct DetailsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingModal = false
    @State private var isEditingDescription = false
    @ObservedObject var project: Project // Fetch the project from CoreData
    @State private var isShowingImagePicker = false

    var body: some View {
            VStack(alignment: .leading) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Contact Information")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showingModal = true
                            }) {
                                Image(systemName: "plus")
                            }
                            .foregroundColor(.white)
                            .buttonStyle(BorderlessButtonStyle())
                            .sheet(isPresented: $showingModal) {
                                ContactModalView(selectedContact: $project.contact, isPresented: $showingModal, dismiss: {
                                    showingModal = false
                                })
                            }
                        }.padding(.bottom)
                    
                    //display the contact here as displayed in contactlistview when creating or choosing a contact in the modal
                    
                    if let contact = project.contact {
                        VStack(alignment: .leading){
                            HStack {
                                Image(systemName: "person.fill")
                                Text("\(contact.name ?? "Unknown")")
                            }
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("\(contact.email ?? "Unknown")")
                            }
                            HStack {
                                Image(systemName: "phone.fill")
                                Text(" \(contact.phone ?? "Unknown")")
                            }
                            HStack {
                                Image(systemName: "location.fill")
                                Text(" \(contact.address ?? "Unknown")")
                            }
                        }.padding(.bottom)
                    }

                    
                    
                    HStack{
                        Text("Project Description")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "pencil")
                            .onTapGesture {
                                isEditingDescription.toggle()
                            }
                    }.padding(.bottom)
                    
                        if isEditingDescription {
                            TextEditor(text: $project.projectDescription.bound)
                                .padding(.bottom)
                                .onChange(of: project.projectDescription) { _ in
                                    saveContext()
                                }
                        } else {
                            Text(project.projectDescription.bound)
                        }

                    
                    Spacer()
                }
                .padding()
                
                Divider()
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Gallery")
                            .font(.headline)
                        
                        Spacer()
                        
#if os(macOS)
Button(action: {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canCreateDirectories = false
    panel.canChooseFiles = true
    panel.allowedFileTypes = ["png", "jpg", "jpeg"]
    if panel.runModal() == .OK {
        for url in panel.urls {
            if let image = NSImage(contentsOf: url) {
                let newImage = GalleryImage(context: viewContext)
                newImage.id = UUID()
                newImage.imageData = image.tiffRepresentation // Save the original NSImage data
                newImage.project = project
            }
        }
        saveContext()
    }
}) {
    Image(systemName: "plus")
}
.buttonStyle(BorderlessButtonStyle())
#endif

#if os(iOS)
Button(action: {
    isShowingImagePicker = true
}) {
    Image(systemName: "plus")
}.foregroundColor(.white)
.sheet(isPresented: $isShowingImagePicker) {
    ImagePicker(selectedImage: $selectedImage)
        .onChange(of: selectedImage) { newImage in
            if let newImage = newImage {
                let newGalleryImage = GalleryImage(context: viewContext)
                newGalleryImage.id = UUID()
                newGalleryImage.imageData = newImage.pngData() // Convert the UIImage to Data
                newGalleryImage.project = project
                saveContext()
            }
        }
}
#endif


                    }
                    .padding(.bottom)
                    
                    #if os(macOS)
                    if let imagesSet = project.galleryImage as? Set<GalleryImage>, !imagesSet.isEmpty {
                        let imagesArray = Array(imagesSet)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                            ForEach(imagesArray, id: \.id) { galleryImage in
                                if let imageData = galleryImage.imageData, let nsImage = NSImage(data: imageData) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .contextMenu {
                                            Button(action: {
                                                viewContext.delete(galleryImage)
                                                saveContext()
                                            }) {
                                                Text("Delete")
                                                Image(systemName: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    } else {
                        Text("Select images")
                    }
                    #endif
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
    private func saveContext() {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    
    // Call this function whenever you make a change that you want to save
    private func updateProject() {
            saveContext()
        }
}

extension Optional where Wrapped == String {
    var bound: String {
        get { return self ?? "" }
        set { self = newValue }
    }
}

#if os(macOS)
extension Data {
    var pngData: Data? {
        guard let imageRep = NSBitmapImageRep(data: self),
              let pngData = imageRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData
    }
}
#endif




import SwiftUI
import CoreData

struct ContactModalView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.name, ascending: true)],
        animation: .default)
    private var contacts: FetchedResults<Contact>
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var showingAddContact = false
    @Binding var selectedContact: Contact?
    @Binding var isPresented: Bool
    var dismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                dismiss()
            }
            
            VStack {
                HStack {
                    TextField("Search...", text: $searchText)
                        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .background(Color(.darkGray))
                        .cornerRadius(10)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    Button(action: {
                        showingAddContact = true
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                    .buttonStyle(BorderlessButtonStyle())
                    .sheet(isPresented: $showingAddContact) {
                        AddContactView()
                    }
                }
                .padding([.horizontal, .top])
                
                List {
                    ForEach(filteredContacts, id: \.self) { contact in
                        HStack {
                            Button(action: {
                                selectedContact = contact
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "person.crop.circle")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                    VStack(alignment: .leading) {
                                        Text(contact.name ?? "Unknown")
                                            .font(.headline)
                                        Text(contact.email ?? "")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            Spacer()
                        }
                        .contextMenu {
                            Button(action: {
                                viewContext.delete(contact)
                                do {
                                    try viewContext.save()
                                } catch {
                                    print("Failed to delete contact: \(error)")
                                }
                            }) {
                                Text("Delete Contact")
                                Image(systemName: "trash")
                            }
                        }
                    }
                }.frame(minWidth: 100, idealWidth: 300, maxWidth: .infinity, minHeight: 100, idealHeight: 250, maxHeight: .infinity)

                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .font(.headline)
                        
                }.padding()
            }
            .navigationTitle("Contacts")
        }
    }
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return Array(contacts)
        } else {
            return Array(contacts).filter {
                $0.name?.contains(searchText) ?? false ||
                $0.email?.contains(searchText) ?? false ||
                $0.phone?.contains(searchText) ?? false ||
                $0.address?.contains(searchText) ?? false
            }
        }
    }
}

struct ImagePickerButton: View {
    #if os(iOS)
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    #endif

    var body: some View {
        Button(action: {
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    let image = NSImage(contentsOf: url)
                    // Use the image
                }
            }
            #elseif os(iOS)
            isShowingImagePicker = true
            #endif
        }) {
            Text("Open Image Picker")
        }
        #if os(iOS)
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        #endif
    }
}


#if os(iOS)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.selectedImage = nil
            picker.dismiss(animated: true)
        }
    }
}

#endif
