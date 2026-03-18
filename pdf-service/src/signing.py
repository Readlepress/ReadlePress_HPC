"""
PDF signing with pyhanko.
Signs PDFs with eMudhra DSC. Falls back to unsigned in development when cert unavailable.
"""
import os
import logging
from io import BytesIO

logger = logging.getLogger(__name__)


def sign_pdf(pdf_bytes: bytes, cert_path: str | None = None, key_path: str | None = None) -> bytes:
    """
    Sign a PDF with eMudhra DSC.
    Falls back to returning unsigned PDF when cert/key not available (e.g. development).
    """
    cert = cert_path or os.getenv("EMUDHRA_SIGNING_CERT_PATH")
    key = key_path or os.getenv("EMUDHRA_SIGNING_KEY_PATH")

    if not cert or not key or not os.path.isfile(cert) or not os.path.isfile(key):
        logger.warning(
            "eMudhra signing cert/key not available. Returning unsigned PDF. "
            "Set EMUDHRA_SIGNING_CERT_PATH and EMUDHRA_SIGNING_KEY_PATH for production."
        )
        return pdf_bytes

    try:
        from pyhanko.sign import signers
        from pyhanko.pdf_utils.reader import PdfFileReader
        from pyhanko.pdf_utils.incremental_writer import IncrementalPdfFileWriter

        signer = signers.SimpleSigner.load(key, cert)
        reader = PdfFileReader(BytesIO(pdf_bytes))
        writer = IncrementalPdfFileWriter.from_reader(reader)

        meta = signers.PdfSignatureMetadata(
            field_name="ReadlePress_HPC_Signature",
            signer_name="ReadlePress HPC Service",
        )
        out = BytesIO()
        signers.sign_pdf(
            writer,
            signature_meta=meta,
            signer=signer,
            output=out,
        )
        return out.getvalue()
    except Exception as e:
        logger.warning("PDF signing failed, returning unsigned PDF: %s", e)
        return pdf_bytes
