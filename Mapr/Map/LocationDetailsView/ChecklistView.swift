import SwiftUI
import CoreData

class ChecklistViewModel: ObservableObject {
    @Published var checklistItems: [ChecklistItem] = []
    private var viewContext: NSManagedObjectContext?
    private var project: Project?
    @NSManaged public var children: NSSet?


    func setup(viewContext: NSManagedObjectContext, project: Project) {
        self.viewContext = viewContext
        self.project = project
        fetchChecklistItems()
    }

    func fetchChecklistItems() {
        guard let viewContext = viewContext, let project = project else { return }
        
        let fetchRequest: NSFetchRequest<ChecklistItem> = ChecklistItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChecklistItem.creationDate, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "project == %@", project.objectID)

        do {
            checklistItems = try viewContext.fetch(fetchRequest)
            print(checklistItems) // Print the fetched items
        } catch {
            print("Failed to fetch checklist items: \(error)")
        }
    }




    private func flatten(items: [ChecklistItem]) -> [ChecklistItem] {
        var flattenedItems: [ChecklistItem] = []
        for item in items {
            flattenedItems.append(item)
            if let childrenSet = item.children as? Set<ChecklistItem> {
                let childrenArray = Array(childrenSet)
                flattenedItems.append(contentsOf: flatten(items: childrenArray))
            }
        }
        return flattenedItems
    }


    func saveContext() {
        guard let viewContext = viewContext else { return }
        
        do {
            try viewContext.save()
            fetchChecklistItems() // Fetch the checklist items again after saving the context.
        } catch {
            print("Failed to save context: \(error)") // Print the error
        }
    }

}


struct ChecklistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var project: Project
    @ObservedObject var viewModel: ChecklistViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                Text("Item")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                Text("Checked")
                    .frame(width: 100)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                Text("Actions")
                    .frame(width: 100)
                    .padding()
                    .background(Color.gray.opacity(0.2))
            }
            .font(.headline)
            
            ForEach(viewModel.checklistItems, id: \.id) { checklistItem in
                checklistRow(checklistItem: checklistItem)
                if let childrenSet = checklistItem.children as? Set<ChecklistItem> {
                    let childrenArray = Array(childrenSet).sorted(by: { $0.creationDate ?? Date() < $1.creationDate ?? Date() })
                    ForEach(childrenArray, id: \.id) { child in
                        checklistRow(checklistItem: child)
                            .padding(.leading, 20)
                    }
                }
            }



            
            Button(action: {
                let newChecklistItem = ChecklistItem(context: self.viewContext)
                newChecklistItem.id = UUID() // Assign a new UUID to each ChecklistItem object
                newChecklistItem.item = ""
                newChecklistItem.isChecked = false
                newChecklistItem.project = project
                print(newChecklistItem) // Print the newChecklistItem
                viewModel.saveContext()
            }) {
                Text("Add Row")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 10)
        }
        .padding()
        .onAppear {
            viewModel.setup(viewContext: viewContext, project: project)
        }
    }
    
    private func checklistRow(checklistItem: ChecklistItem) -> some View {
        HStack(spacing: 0) {
            TextField("Description", text: Binding(get: {
                checklistItem.item ?? ""
            }, set: {
                checklistItem.item = $0
                try? viewContext.save()
            }))
            .frame(maxWidth: .infinity)
            .padding()
            .cornerRadius(5)
            .textFieldStyle(PlainTextFieldStyle())

            Toggle("", isOn: Binding(get: {
                checklistItem.isChecked
            }, set: {
                checklistItem.isChecked = $0
                viewModel.saveContext()
            }))
            .frame(width: 100)
            .padding()
            .cornerRadius(5)

            HStack(spacing: 20) {
                Button(action: {
                    if let parent = checklistItem.parent {
                        parent.removeFromChildren(checklistItem) // Remove the item from the parent's children
                        if parent.children?.count == 0 {
                            viewContext.delete(parent)
                        }
                    } else {
                        viewContext.delete(checklistItem)
                    }
                    viewModel.saveContext() // Call saveContext on the viewModel
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.body)
                }
                .buttonStyle(BorderlessButtonStyle())



                if checklistItem.parent == nil {
                    Button(action: {
                        let newChecklistItem = ChecklistItem(context: self.viewContext)
                        newChecklistItem.id = UUID() // Assign a new UUID to each ChecklistItem object
                        newChecklistItem.item = ""
                        newChecklistItem.isChecked = false
                        newChecklistItem.creationDate = Date() // Set the creation date to the current date
                        checklistItem.addToChildren(newChecklistItem) // Manually add the new item to the parent's children
                        newChecklistItem.parent = checklistItem // Set the parent of the new item
                        viewModel.saveContext() // Call saveContext on the viewModel
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                            .font(.body)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                }
            }
            .padding()
            .cornerRadius(5)
            .frame(width: 100)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(5)
    }
}
