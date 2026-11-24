create or replace procedure it.PRG_IMP_RET_VIRTUAL IS
  v_cod_proveedor number;
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
      from ge_ret_vir_proveedores_tmp t
     where t.tip_doc_informado = 'RUC'
     and trim(upper(t.estado)) = 'ACEPTADO'
     order by t.fec_retencion;

  --función para obtener el código de ente
  FUNCTION FUG_OBT_COD_ENTE(p_nro_factura in varchar2,
                            p_fecha       in varchar2,
                            p_nro_ruc     in varchar2) RETURN NUMBER IS
    v_cod_ente number;
  begin
    select c.cod_ent_proveedor
      into v_cod_ente
      from pv_compras c
     where c.nro_factura = p_nro_factura
       and to_char(c.fec_pago, 'dd/mm/yyyy') = p_fecha
       and substr(c.ruc, 1, instr(c.ruc, '-') - 1) = p_nro_ruc;
    return v_cod_ente;
  Exception
    when others then
      v_cod_ente := null;
      return v_cod_ente;
  end;
Begin
  For ret in ret_virtuales_tmp loop
    v_cod_proveedor := FUG_OBT_COD_ENTE(ret.nro_factura,to_char(ret.fec_retencion,'dd/mm/yyyy'),ret.nro_doc_informado);
    --Actualiza el Nro. de Retencion, y el estado a Emitido.
      Update ge_ret_vir_proveedores r
         set r.nro_ret_tesaka = substr(ret.nro_retencion, 1, 3) ||substr(ret.nro_retencion, 5, 3) ||substr(ret.nro_retencion, 9),
             r.estado         = 'E',
             r.fec_cam_estado = sysdate
       where r.cod_proveedor = v_cod_proveedor
         and to_char(r.fec_pago, 'dd/mm/yyyy') = to_char(ret.fec_retencion, 'dd/mm/yyyy')
         and r.nro_factura = ret.nro_factura
         and r.estado = 'G';
    IF SQL%NOTFOUND THEN
          null; -- Si no puede actualizar no debe hacer nada.   
    END IF;
  End Loop;
End;
/

