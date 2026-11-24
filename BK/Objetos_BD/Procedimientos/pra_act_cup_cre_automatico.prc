CREATE OR REPLACE PROCEDURE IT.PRA_ACT_CUP_CRE_AUTOMATICO
 IS
   --- Cursor de cupones vencidos
   cursor c_cupon is
     select CU.NRO_CUENTA, CU.NRO_CUPON, NVL(cu.MTO_INTERES,0) MTO_INTERES, CU.FEC_VENCIMIENTO, CU.ROWID linea
       from AH_CUPONES CU, AH_CTA_CERTIFICADOS CD
      where CD.NRO_CUENTA = CU.NRO_CUENTA
        and CD.ESTADO NOT IN ('A', 'T','P','C','X')
           AND (cu.estado = 'C' AND cd.cre_automatico = 'S')
           and cd.cod_modalidad != 34;--se agrega para que no actualice los productos cda-d
BEGIN
   for r_cup in c_cupon loop
      --------
      update AH_CUPONES
         set ESTADO = 'E'
       where rowid = r_cup.linea;
   end loop;
END;
/
