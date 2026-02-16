#include <OpenColorIO/OpenColorIO.h>
#include <iostream>

int main()
{
    std::cout << "OCIO Version: "
              << OCIO::GetVersion() << std::endl;
    return 0;
}
