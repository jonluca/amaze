import os


def main():
    print('test')
    pic = open(os.path.join(os.getcwd(), 'pics', 'IMG_1596.PNG'), mode='rb').read()


if __name__ == '__main__':
    main()
