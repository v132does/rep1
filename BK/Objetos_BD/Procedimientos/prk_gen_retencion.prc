CREATE OR REPLACE PROCEDURE IT.PRK_GEN_RETENCION is
  cursor c_reten is
  select a.cod_proveedor, a.fec_pago, a.nro_factura, a.importe, a.cod_moneda, a.nro_retencion, a.monto_iva,
         a.monto_retencion, a.estado, a.cotizacion, a.mto_renta, a.mto_ret_renta, a.tipo_ret
    from pv_ret_proveedores a;

  v_cod_proveedor ge_ret_proveedores.cod_proveedor%type;
  v_nro_retencion ge_ret_proveedores.nro_retencion%type;
  v_encontro      varchar2(1):='N';
  v_nro_factura   ge_ret_proveedores.nro_factura%type;
  v_nro_timbrado     ge_ret_proveedores.nro_timbrado%type;
  v_fec_vig_timbrado ge_ret_proveedores.fec_vig_timbrado%type;
  v_cod_ofi_hacienda ba_oficinas.cod_oficina%type;
  v_pun_expedicion   number(3);
begin
  for x in c_reten loop
    v_cod_proveedor := x.cod_proveedor;
    v_nro_retencion := null;
    v_encontro      := 'N';
    v_nro_factura   := x.nro_factura;
    ---Obtener el nro_retencion que está en ge_par_dinamicos
    if nvl(x.tipo_ret,'N') = 'E' then /*Factura del exterior*/
      begin
         select nvl(to_number(par.val_parametro),0)+1
           into v_nro_retencion
           from ge_par_dinamicos par
          where par.parametro = 'SIG_NRO_RET_EXTER';
      exception
         when others then
           v_nro_retencion := null;
           raise_application_error(-20001, 'Error al obtener SIG_NRO_RET_EXTER: '||sqlerrm);
      end;
    else
      --Obtiene el numero de retención, timbrado y fecha de vigencia del timbrado
      v_cod_ofi_hacienda := fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, fug_obt_ofi_matriz());
      if v_cod_ofi_hacienda is null then
        raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||fug_obt_ofi_matriz());
      end if;
      v_pun_expedicion   := pab_iva.fu_obt_pun_expedicion('R');
      pab_iva.pr_obt_nro_factura(31, pag_cal.fu_obt_fec_actual(1), 'R', v_nro_retencion, v_nro_timbrado, v_fec_vig_timbrado);--La numeracion es unica para todas las oficinas
      v_nro_retencion := v_cod_ofi_hacienda || lpad(v_pun_expedicion,3,'0')|| lpad(to_char(v_nro_retencion),7,'0');
      --
      /*begin
         select nvl(to_number(par.val_parametro),0)+1
           into v_nro_retencion
           from ge_par_dinamicos par
          where par.parametro = 'SIG_NRO_RETENCION';
      exception
         when others then
           v_nro_retencion := null;
           raise_application_error(-20001, 'Error al obtener SIG_NRO_RETENCION: '||sqlerrm);
      end;*/
    end if;
    begin      
       --Antes de insertar en ge_ret_proveedor verifica si el N° de factura es valido
       If fue_val_es_numerico(replace(replace(replace(x.nro_factura,'-',''),'.',''),' ','')) = 'N' Then
          raise_application_error(-20002,'Número de Documento invalido. Formato : 999-999-9999999 '||x.nro_factura);
       Elsif length(x.nro_factura) <> 15 then
          raise_application_error(-20002,'Numero de Documento debe tener el formato: 999-999-9999999 '||x.nro_factura);
       Else
          if instr(x.nro_factura,'.') > 0 or instr(x.nro_factura,' ') > 0 then
             v_nro_factura := replace(replace(x.nro_factura,'.','-'),' ','-'); 
          end if;
       End If;    
       ------------------------
       Begin
        Select 'S'
          into v_encontro
          from ge_ret_proveedores
         Where cod_proveedor = x.cod_proveedor
           and nro_factura = v_nro_factura
           and estado = 'N';
       Exception
          when others then
             v_encontro := 'N';
       End;  
       
       If v_encontro = 'S' then
          raise_application_error(-20002,'Numero de Factura duplicado para el mismo Proveedor : '||x.nro_factura);
       else
          insert into ge_ret_proveedores(cod_proveedor, fec_pago, nro_factura, importe, cod_moneda, nro_retencion,
          monto_iva, monto_retencion, estado, cotizacion, mto_renta, mto_ret_renta, nro_timbrado, fec_vig_timbrado)
          values 
          (x.cod_proveedor, x.fec_pago, v_nro_factura, x.importe, x.cod_moneda, v_nro_retencion,
          x.monto_iva, x.monto_retencion, 'N', x.cotizacion, x.mto_renta, x.mto_ret_renta, v_nro_timbrado, v_fec_vig_timbrado);
       end if;    
    exception
      when others then
         raise_application_error(-20003, 'Error al insertar en ge_ret_proveedores : '||x.cod_proveedor||' '||sqlerrm);
    end;
    --Actualizar parametro dinámico del nro_retencion
    if nvl(x.tipo_ret,'N') = 'E' then /*Factura del exterior*/
      begin
         update ge_par_dinamicos par
            set par.val_parametro = v_nro_retencion
          where par.parametro = 'SIG_NRO_RET_EXTER';
      exception
         when others then
           raise_application_error(-20004, 'Error al actualizar parametro SIG_NRO_RET_EXTER: '||sqlerrm);
      end;
    /*else
      begin
         update ge_par_dinamicos par
            set par.val_parametro = v_nro_retencion
          where par.parametro = 'SIG_NRO_RETENCION';
      exception
         when others then
           raise_application_error(-20005, 'Error al actualizar parametro SIG_NRO_RETENCION: '||sqlerrm);
      end;*/
    end if;
  end loop;
exception
  when others then
     raise_application_error(-20000, 'Error al ejecutar procedimiento: '||v_cod_proveedor||' '||sqlerrm);
end;
/

