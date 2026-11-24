CREATE OR REPLACE TRIGGER IT.tb_cb_lib_ventas_det
  before DELETE OR INSERT OR UPDATE on cb_lib_ventas_det
  for each row
begin
   if inserting then
        --- Totalizar en el padre los montos en moneda local
        update cb_lib_ventas v
           set v.mto_exento_gs     = nvl(v.mto_exento_gs,0) + nvl(:new.mto_exento_gs,0),
               v.mto_gravado_5_gs  = nvl(v.mto_gravado_5_gs,0) + nvl(:new.mto_gra_5_gs,0),
               v.mto_gravado_10_gs = nvl(v.mto_gravado_10_gs,0) + nvl(:new.mto_gra_10_gs,0),
               v.impuesto_5_gs     = nvl(v.impuesto_5_gs,0) + nvl(:new.impuesto_5_gs,0),
               v.impuesto_10_gs    = nvl(v.impuesto_10_gs,0) + nvl(:new.impuesto_10_gs,0),
               v.mto_exento        = nvl(v.mto_exento,0) + nvl(:new.mto_exento,0),
               v.mto_gravado_5     = nvl(v.mto_gravado_5,0) + nvl(:new.mto_gravado_5,0),
               v.mto_gravado_10    = nvl(v.mto_gravado_10,0) + nvl(:new.mto_gravado_10,0),
               v.impuesto_5        = nvl(v.impuesto_5,0) + nvl(:new.impuesto_5,0),
               v.impuesto_10       = nvl(v.impuesto_10,0) + nvl(:new.impuesto_10,0)
         where v.nro_factura  = :new.nro_factura
           and v.nro_timbrado = :new.nro_timbrado
           and v.tip_comprobante = :new.tip_comprobante
           and v.fecha = :new.fecha;

       if sql%notfound then
          raise_application_error(-20000,
          'Padre para sumarizar no encontrado, Fact.'||:new.nro_factura||' Tim.'||:new.nro_timbrado);
       end if;
   end if;
end tb_cb_lib_ventas_det;
/

