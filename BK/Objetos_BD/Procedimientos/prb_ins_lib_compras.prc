CREATE OR REPLACE PROCEDURE IT.PRB_INS_LIB_COMPRAS
 (r_lib IN cb_lib_compras%ROWTYPE
 )
 IS
   v_existe varchar2(1) := 'S';
   v_cuota  cb_lib_compras.can_cuota%type := 0;
BEGIN
   begin
      select 'S'
        into   v_existe
        from   cb_lib_compras
       where  nro_factura   = r_lib.nro_factura
         and  cod_persona   = r_lib.cod_persona
		     and  nro_documento = r_lib.nro_documento
         /* CRO- P.S 07/11/2014 - Se agrega filtro por Timbrado para facturas ya existentes e inserte nuevos registros*/
         and  nro_timbrado  = r_lib.nro_timbrado ;
   exception
      when no_data_found then
         v_existe := 'N';
   end;
   -- verificar la cuota dependiendo del tipo de factura --
      if r_lib.tipo = 'CO' then
         v_cuota := 0;
      elsif r_lib.tipo = 'CR' then
         v_cuota := 1;
      end if;
   ---
   if nvl(v_existe,'N') = 'N' then

      insert into cb_lib_compras(
      fecha, nro_factura, nro_timbrado, tipo,cod_persona,
      mto_exento,mto_gravado_10,impuesto_10,mto_gravado_5,impuesto_5,
      nro_documento,raz_social, cod_ofi_origen, cod_ent_proveedor,
		  fec_pago,can_cuota, tip_origen,tip_comprobante)
      values(
      r_lib.fecha, r_lib.nro_factura, r_lib.nro_timbrado, r_lib.tipo, r_lib.cod_persona,
      r_lib.mto_exento, r_lib.mto_gravado_10, r_lib.impuesto_10,
      r_lib.mto_gravado_5, r_lib.impuesto_5,
      r_lib.nro_documento, r_lib.raz_social, r_lib.cod_ofi_origen,
		  r_lib.cod_ent_proveedor, r_lib.fec_pago, v_cuota, r_lib.tip_origen,r_lib.tip_comprobante);
      
   else
     
      update cb_lib_compras
      set    mto_exento         = nvl(mto_exento,0) + nvl(r_lib.mto_exento,0),
             mto_gravado_10     = nvl(mto_gravado_10,0) + nvl(r_lib.mto_gravado_10,0),
             impuesto_10        = nvl(impuesto_10,0) + nvl(r_lib.impuesto_10,0),
             mto_gravado_5      = nvl(mto_gravado_5,0) + nvl(r_lib.mto_gravado_5,0),
             impuesto_5         = nvl(impuesto_5,0) + nvl(r_lib.impuesto_5,0),
             can_cuota          = v_cuota
      where  nro_factura    = r_lib.nro_factura
        and  cod_persona    = r_lib.cod_persona
		    and  nro_documento  = r_lib.nro_documento;
        
      if sql%notfound then
         raise_application_error(-20000,'El libro IVA compras no fue actualizado');
      end if;
      
   end if;
   ---
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20001,'Error al insertar en el Libro de Compras. '||sqlerrm);
      end if;

END;
/

