create or replace procedure it.PRA_IMP_RET_VIRTUAL IS
  v_cod_cliente number;
  Cursor ret_virtuales_tmp is
    select t.estado,
           t.nro_retencion,
           t.tip_doc_informado,
           t.nro_doc_informado,
           t.identificacion,
           t.nombre,
           t.nro_control,
           t.fec_retencion,
           t.nro_factura,
           t.timbrado
      from ge_ret_vir_clientes_tmp t
     where t.tip_doc_informado = 'RUC'
     and trim(upper(t.estado)) = 'ACEPTADO'
     order by t.fec_retencion;

  --función para obtener el código de PERSONA del cliente
  FUNCTION FUG_OBT_DAT_CLIENTE (p_nro_factura in varchar2,
                                p_fecha       in varchar2) RETURN NUMBER IS
    v_cod_persona number;
  begin
    select c.cod_persona
      into v_cod_persona
      from ge_inr_retenciones c
     where c.nro_factura = p_nro_factura
       and to_char(c.fec_retencion, 'dd/mm/yyyy') = p_fecha;
    return v_cod_persona;
  Exception
    when others then
      v_cod_persona := null;
      return v_cod_persona;
  end;
Begin
  For ret in ret_virtuales_tmp loop
    v_cod_cliente := FUG_OBT_DAT_CLIENTE(ret.nro_factura,to_char(ret.fec_retencion,'dd/mm/yyyy'));
    --Actualiza el Nro. de Retencion, y el estado a Emitido.
      Update ge_ret_vir_clientes r
         set r.nro_ret_tesaka = substr(ret.nro_retencion, 1, 3) ||substr(ret.nro_retencion, 5, 3) ||substr(ret.nro_retencion, 9),
             r.estado         = 'E',
             r.fec_cam_estado = sysdate
       where r.cod_persona = v_cod_cliente
         and to_char(r.fec_pago, 'dd/mm/yyyy') = to_char(ret.fec_retencion, 'dd/mm/yyyy')
         and r.nro_factura = ret.nro_factura
         and r.estado = 'G';
         
      update ge_inr_retenciones g
         set g.nro_ret_tesaka = substr(ret.nro_retencion, 1, 3) ||substr(ret.nro_retencion, 5, 3) ||substr(ret.nro_retencion, 9),
             g.estado         = 'E'
       where g.cod_persona = v_cod_cliente
         and g.nro_factura = ret.nro_factura
         and g.fec_retencion = to_char(ret.fec_retencion, 'dd/mm/yyyy') ;      
         
         
    IF SQL%NOTFOUND THEN
          null; -- Si no puede actualizar no debe hacer nada.
    END IF;
  End Loop;
End;
/

