CREATE OR REPLACE TRIGGER IT."TA_CB_LIB_VENTAS_DET"
  after DELETE  on cb_lib_ventas_det
  for each row
    /* para actualizar datos de facturas mal generadas en cobro de préstamos */
begin
   if deleting then
      --- Totalizar en el padre los montos
        update cb_lib_ventas v
           set v.mto_exento_gs     = nvl(v.mto_exento_gs,0) - nvl(:old.mto_exento_gs,0),
               v.mto_gravado_5_gs  = nvl(v.mto_gravado_5_gs,0) - nvl(:old.mto_gra_5_gs,0),
               v.mto_gravado_10_gs = nvl(v.mto_gravado_10_gs,0) - nvl(:old.mto_gra_10_gs,0),
               v.impuesto_5_gs     = nvl(v.impuesto_5_gs,0) - nvl(:old.impuesto_5_gs,0),
               v.impuesto_10_gs    = nvl(v.impuesto_10_gs,0) - nvl(:old.impuesto_10_gs,0),
               v.mto_exento        = nvl(v.mto_exento,0) - nvl(:old.mto_exento,0),
               v.mto_gravado_5     = nvl(v.mto_gravado_5,0) - nvl(:old.mto_gravado_5,0),
               v.mto_gravado_10    = nvl(v.mto_gravado_10,0) - nvl(:old.mto_gravado_10,0),
               v.impuesto_5        = nvl(v.impuesto_5,0) - nvl(:old.impuesto_5,0),
               v.impuesto_10       = nvl(v.impuesto_10,0) - nvl(:old.impuesto_10,0)
         where v.nro_factura  = :old.nro_factura
           and v.nro_timbrado = :old.nro_timbrado;
       if sql%notfound then
          raise_application_error(-20000,
          'Padre para sumarizar no encontrado, Fact.'||:old.nro_factura||' Tim.'||:old.nro_timbrado);
       end if;
   end if;
end ta_cb_lib_ventas_det;
/

