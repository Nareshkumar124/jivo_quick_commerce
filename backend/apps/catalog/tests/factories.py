import io
from decimal import Decimal

import factory
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

from apps.catalog.models import Category, Product, ProductImage, ProductVariant


def image_upload(
    width: int = 400, height: int = 300, fmt: str = "PNG", color=(200, 120, 40), name=None
) -> SimpleUploadedFile:
    buffer = io.BytesIO()
    mode = "RGBA" if fmt == "PNG" else "RGB"
    Image.new(mode, (width, height), color).save(buffer, fmt)
    ext = {"JPEG": "jpg"}.get(fmt, fmt.lower())
    return SimpleUploadedFile(name or f"photo.{ext}", buffer.getvalue())


class CategoryFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Category

    name = factory.Sequence(lambda n: f"Category {n}")
    slug = factory.Sequence(lambda n: f"category-{n}")


class ProductFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Product

    name = factory.Sequence(lambda n: f"Jivo Product {n}")
    slug = factory.Sequence(lambda n: f"jivo-product-{n}")
    category = factory.SubFactory(CategoryFactory)
    gst_rate = Decimal("5.00")


class VariantFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = ProductVariant

    product = factory.SubFactory(ProductFactory)
    sku = factory.Sequence(lambda n: f"JV-TEST-{n:05d}")
    name = "1 L"
    net_quantity = "1 L"
    unit_value = Decimal("1000")
    unit = "ml"
    mrp = Decimal("349.00")
    selling_price = Decimal("279.00")
    max_qty_per_order = 5


class ProductImageFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = ProductImage

    product = factory.SubFactory(ProductFactory)
    image = factory.LazyFunction(image_upload)
    alt_text = "Bottle"
