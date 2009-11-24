#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>

int main( int argc, char * argv[] )
{
    int ret = -1, fd = -1;
    struct stat fileStat;
    int fsize = 0; 
    char * fbuf = NULL, * delBegin = NULL;
    char * l = NULL, * f = NULL, * p = NULL;
    char filename[256];

    if ( argc != 2 )
    {
        printf( "USAGE: %s dest_file\n", argv[0] );
        goto exit;
    }

    fd = open( argv[1], O_RDWR );
    if ( fd < 0 )
    {
        printf( "ERROR: can not open dest_file!\n" );
        goto exit;
    }
    
    ret = fstat( fd, &fileStat );
    if ( ret < 0 )
    {
        printf( "ERROR: can not get stat of dest_file.\n" );
        goto exit;
    }
    else
    {
        fsize = fileStat.st_size;
    }

    fbuf = mmap( 0, fsize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0 );
    if ( fbuf == MAP_FAILED )
    {
        printf( "ERROR: mmap dest_file failed.\n" );
        goto exit;
    }

    while ( 1 )
    {
        if ( !fgets( filename, sizeof(filename), stdin ) )
        {
            break;
        }

        for ( p = fbuf, l = fbuf; p < fbuf + fsize; )
        {
            if ( *p == 0x7f )
            {
                if ( !delBegin )
                {
                    delBegin = p;
                }
            }
            else
            {
                delBegin = NULL;

                if ( *p != '!' )
                {
                    p = memchr( p, '\t', fsize - ( p - fbuf ) );
                    if ( p == NULL )
                    {
                        break;
                    }

                    p++;
                    f = p;

                    p = memchr( p, '\t', fsize - ( p - fbuf ) );
                    if ( p == NULL )
                    {
                        break;
                    }

                    if ( strncmp( filename, f, p - f ) == 0 )
                    {
                        l[0] = 0x7f;
                    }
                }
            }

            p = memchr( p, '\n', fsize - ( p - fbuf ) );
            if ( p == NULL )
            {
                break;
            }

            p++;
            l = p;
        }

        if ( delBegin )
        {
            fsize = delBegin - fbuf;
            ftruncate( fd, fsize );
            delBegin = NULL;
        }
    }

exit:
    if ( fbuf != NULL )
    {
        munmap( fbuf, fsize );
    }

    if ( fd >= 0 )
    {
        close(fd);
    }

    return 0;
}
