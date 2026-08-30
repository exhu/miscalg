module linear_alloc;

struct StorageItem(T)
{
  T data;
  uint generation;
}

struct StorageItemHandle
{
  uint index;
  uint generation;
}

struct LinearStorage(T)
{
  StorageItem!T [] items;
  
  
  

}
