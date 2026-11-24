CREATE OR REPLACE TRIGGER IT.ta_ah_tar_debitos_nov
  before insert on ah_tar_debitos_nov
  for each row
DECLARE
   -- local variables here
BEGIN
   /*
   || Definición de importación de archivo MAE_DEB.TXT en la referencia 'TAR_DEBITOS'
   || -------------------------------------------------------------------------------
   || Orden Campo        Función
   || -------------------------------------------------------------------------------
   ||  1 NRO_TARJETA   
   ||  2 ADHERENTE       lpad($param, 2, '0')
   ||  3 NRO_EMISION     lpad($param, 2, '0')
   ||  4 FEC_VENCIMIENTO
   ||  5 FEC_ALTA        decode(substr($param,1,1),'/' ,null, to_Date($param, 'dd/mm/rrrr hh24:mi:ss'))
   ||  6 EMBOZADO
   ||  7 COD_EMBOZADO
   ||  8 FEC_ULT_MOV_POS decode(substr($param,1,1),'/' ,null, to_Date($param, 'dd/mm/rrrr hh24:mi:ss'))
   ||  9 ESTADO
   || 10 FEC_ULT_MOV_ATM decode(substr($param,1,1),'/' ,null, to_Date($param, 'dd/mm/rrrr hh24:mi:ss'))
   || 11 FEC_EMBOZADO    to_date($param, 'dd/mm/yy')
   || 12 EST_PIN
   */
   :new.nro_tarjeta     := trim(substr(:new.fila, 1, 19));
   :new.adherente       := lpad(trim(substr(:new.fila, 20, 2)),2,'0');
   :new.nro_emision     := lpad(trim(substr(:new.fila, 22, 2)),2,'0');
   :new.fec_vencimiento := substr(:new.fila, 24, 7);
   ---
   begin
      :new.fec_alta        := to_date(substr(:new.fila, 31, 17), 'dd/mm/yy hh24/mi/ss');
   exception
      when others then
         null;
   end;
   :new.embozado        := trim(substr(:new.fila, 48, 26));
   :new.cod_embozado    := substr(:new.fila, 74, 6);
   ---
   begin
      :new.fec_ult_mov_pos := to_date(substr(:new.fila, 80, 17), 'dd/mm/yy hh24/mi/ss');
   exception
      when others then
         null;
   end;
   :new.estado := substr(:new.fila, 97, 1);
   ---
   begin
      :new.fec_ult_mov_atm := to_date(substr(:new.fila, 98, 17), 'dd/mm/yy hh24/mi/ss');
   exception
      when others then
         null;
   end;
   begin
      :new.fec_embozado  := to_date(substr(:new.fila, 115, 8), 'dd/mm/yy');
   exception
      when others then
         null;
   end;
   :new.tip_corte     := substr(:new.fila, 123, 1);
   :new.est_pin       := substr(:new.fila, 124, 1);
   /*:new.sucursal      := substr(:new.fila, 125, 2);
   :new.nro_documento := substr(:new.fila, 127, 16);
   :new.ruc           := substr(:new.fila, 143, 11);
   :new.req_embozado  := substr(:new.fila, 154, 1);
   :new.direccion     := substr(:new.fila, 155, 60);
   :new.telefono      := substr(:new.fila, 215, 25);*/
   
   -- Ajuste por cambio de longitud del archivo MAE_DEBM -  DYDMR-12420 
   :new.sucursal      := substr(:new.fila, 125, 4);
   :new.nro_documento := substr(:new.fila, 129, 16);
   :new.ruc           := substr(:new.fila, 145, 11);
   :new.req_embozado  := substr(:new.fila, 156, 1);
   :new.direccion     := substr(:new.fila, 157, 60);
   :new.telefono      := substr(:new.fila, 217, 25);
END;
/

