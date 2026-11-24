create or replace procedure it.prb_ins_iva_venta is
  v_iva_row cb_lib_ventas_det_tmp%rowtype;  
  v_msj_error           varchar2(1000);
  v_iva                      number(18,2) ;
  v_exi_salir             exception;
   cursor c_validacion is
    select a.*
    from cb_fac_man_tmp a
    order by a.cod_persona ;
  -- Universo de clientes --
   cursor c_facturas is
    select distinct a.cod_persona
    from cb_fac_man_tmp a
    order by a.cod_persona ;
begin
  -- Author  : Christian Leiva
  -- Created : 15/02/2016
  -- Purpose : Se realiza la generación de las facturas.
  -- Validaciones --
  for v in c_validacion  loop
     If  v.cod_persona is null then
        v_msj_error := 'ERROR : El código de persona no puede estar NULO. Nro. Documento =  ' || v.nro_documento||' '||v.nombre ;
        raise v_exi_salir;
    end if;
    If  v.nro_documento is null then
        v_msj_error := 'ERROR : El nro. de documento no puede estar NULO. Cod. Persona =  ' || v.nro_documento||' '||v.nombre ;
        raise v_exi_salir;
    end if;
    If  v.nombre is null then
        v_msj_error := 'ERROR : El Nombre de la persona no puede estar NULO. Nro. Documento =  ' || v.nro_documento||' '||v.nombre ;
        raise v_exi_salir;
    end if;
    If  v.descripcion is null then
        v_msj_error := 'ERROR : La descripción de la Factura no puede estar NULO. Nro. Documento =  ' || v.nro_documento||' '||v.nombre ;
        raise v_exi_salir;
    end if;
    If  nvl(v.mto_gravado,0)  = 0 then
        v_msj_error := 'ERROR : El Monto Gravado no puede estar NULO. Nro. Documento =  ' || v.nro_documento||' '||v.nombre ;
        raise v_exi_salir;
    end if;
    if   fug_val_es_numerico(v.cod_persona) != 'S' then
        v_msj_error := 'ERROR : El Código de Persona no es NUMERICO. Verifique. Cod. Doc. =  ' ||v.nro_documento||' - '||v.cod_persona||' '||v.nombre ;
        raise v_exi_salir;
    end if;   
    if instr(v.cod_persona,'.') > 0 then
          v_iva_row.cod_persona :=  replace(v.cod_persona, '.') ;
   else
          v_iva_row.cod_persona  := v.cod_persona ;
   end if;
    if instr(v.nro_documento,'.') > 0 then
          v_iva_row.nro_doc_persona :=  replace(v.nro_documento, '.') ;
   else
          v_iva_row.nro_doc_persona  := v.nro_documento ;
   end if;
    IF  nvl(v.impuesto,0) = 0 then
        v_msj_error := 'ERROR : El monto del Iva no puede estar NULO. Nro. Documento = ' || v.nro_documento||' '||v.nombre ;
        raise v_exi_salir;
    end if;
    -- Consistencia de datos --
     begin
        select cod_persona, nro_documento
          into v_iva_row.cod_persona, v_iva_row.nro_doc_persona
          from ba_personas b
         where b.cod_persona =  v.cod_persona ;
      exception
        when no_data_found then
          v_msj_error := 'No Existe la Persona en la Base de Datos :  ' || v.cod_persona||' '||v.nombre ;
          raise v_exi_salir;
      end;         
      -- Verifica si el nro. de documento corresponde a la persona --
       if v.nro_documento != to_char(v_iva_row.nro_doc_persona) then
            v_msj_error := 'ERROR : El Nro. de Documento NO corresponde a la Persona. Verifique. Nro. Documento =  : ' || v.nro_documento||' '||v.nombre ;
            raise v_exi_salir;
       end if;       
      -- Control del Iva --
      v_iva := (v.mto_gravado*v.tasa) / 100 ;
      if abs (v_iva  - v.impuesto) > 5 then
         v_msj_error := 'ERROR : El monto del Iva no cuadra con su Gravada. Verifique. Nro. Documento =  '|| v.nro_documento||' '||v.nombre ;
         raise v_exi_salir;
      end if;
  end loop;
  ------------------------------------------------------------------
  begin  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_iva_row.fecha                    :=  pag_cal.fu_obt_fec_actual(2) ;
  v_iva_row.cod_usuario         := user ;
  v_iva_row.cod_modulo         := 2;
  v_iva_row.cod_modalidad    := 21;
  v_iva_row.cod_tra_padre     := 100;
  v_iva_row.cod_mod_padre   := 2 ;
  v_iva_row.cod_mad_padre   := 21 ;
  v_iva_row.cod_moneda        := 'GS';
  v_iva_row.cod_ofi_origen    := '31';
  v_iva_row.tip_comprobante := 'F' ;
  v_iva_row.tip_venta             := 'CO';
  v_iva_row.nro_secuencia    :=  0   ;
  for f in c_facturas  loop
      v_iva_row.cod_persona := f.cod_persona ;
     for v in ( Select t.*  from cb_fac_man_tmp t where t.cod_persona = f.cod_persona )
       loop
              v_iva_row.nro_secuencia     :=  v_iva_row.nro_secuencia + 1;
              v_iva_row.nom_completo    := v.nombre;
              -- Reemplaza (.)
               if instr(f.cod_persona,'.') > 0 then
                      v_iva_row.cod_persona :=  replace(f.cod_persona, '.') ;
               else
                      v_iva_row.cod_persona  := f.cod_persona ;
               end if;
                if instr(v.nro_documento,'.') > 0 then
                      v_iva_row.nro_doc_persona :=  replace(v.nro_documento, '.') ;
               else
                      v_iva_row.nro_doc_persona  := v.nro_documento ;
               end if;             
              v_iva_row.descripcion          := substr(trim(v.descripcion),1,35) ;
              v_iva_row.mto_gravado_10 := v.mto_gravado ;
              v_iva_row.mto_gra_10_gs   := v.mto_gravado ;
              v_iva_row.impuesto_10       := v.impuesto ;
              v_iva_row.impuesto_10_gs := v.impuesto ;
               v_iva_row.hora                    :=  fug_ini_hora(sysdate,'hh24:mi:ss');
              -- Se realiza la inserción --
             insert into cb_lib_ventas_det_tmp values v_iva_row;
       end loop;
  end loop;
 commit;
EXCEPTION
  WHEN v_exi_salir THEN
    raise_application_error(-20000, v_msj_error);
WHEN OTHERS THEN
   raise_application_error(-20000, 'Error no manejado en el proceso PRB_INS_IVA_VENTA' || sqlerrm);
end prb_ins_iva_venta;
/

