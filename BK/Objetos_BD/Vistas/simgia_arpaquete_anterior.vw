create or replace force view it.simgia_arpaquete_anterior as
select "PQCLIENTE","PQCLASE","PQSEQ","PQFEINI","PQVTO","PQSUC","PQCTA","PQSUB","PQFPRICH","FECHA_HIS"
from simgia_arpaquete_bkp a;

