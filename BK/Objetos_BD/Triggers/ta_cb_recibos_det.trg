CREATE OR REPLACE TRIGGER IT."TA_CB_RECIBOS_DET"
  after INSERT OR DELETE  on cb_recibos_det
  for each row
    /* Trigger que actualza el total del Recibo*/
begin
   if deleting then
      --- Totalizar en el padre los montos
      update cb_recibos v
         set v.tot_recibo = nvl(v.tot_recibo, 0) - nvl(:old.monto,0)
       where nro_recibo = :old.nro_recibo;
      
      if sql%notfound then
         raise_application_error(-20000,
         'Padre para sumarizar no encontrado, Rec. '||:old.nro_recibo);
      end if;
   elsif inserting then
      update cb_recibos v
         set v.tot_recibo =  nvl(v.tot_recibo, 0) + nvl(:new.monto, 0)
         where v.nro_recibo  = :new.nro_recibo;        
       if sql%notfound then
          raise_application_error(-20000,
          'Padre para sumarizar no encontrado, Rec. '||:new.nro_recibo);
       end if;
   end if;
end ta_cb_recibos_det;
/

