CREATE OR REPLACE PROCEDURE IT.PRA_ACT_LIM_CREDITO IS
  CURSOR circuitos IS
    Select t.cod_circuito, t.cod_tip_circuito, t.referencia, t.cod_persona
      from wf_circuitos t
     where t.cod_tip_circuito in (51,82)
       and it.paw_cir.fu_tie_excedido(t.cod_circuito, 1) != 0
	     and t.estado not in ('F','N','C');
BEGIN
  for reg in circuitos loop
    if reg.cod_tip_circuito = 51 then
      delete BA_PER_IMA_DOCUMENTOS
       where cod_persona = reg.cod_persona
         and est_doc != 'A'
         and cod_tip_documento = fug_obt_pardinamico('COD_DOC_SET');
    
      update ge_cta_dat_adicionales
         set val_parametro = fug_obt_pardinamico('ONB_LIM_INICIAL', 3, 334, 'GS')
       where nro_cuenta = reg.referencia
         and parametro = 'LIM_CRE_TRANSACCIONES';
    
      if sql%notfound then
        begin
          insert into ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
          values
            (reg.referencia,
             'LIM_CRE_TRANSACCIONES',
             fug_obt_pardinamico('ONB_LIM_INICIAL', 3, 334, 'GS'));
        exception
          when dup_val_on_index then
            null;
        end;
      end if;
	  update wf_cir_tareas 
         set estado = 'V'
       where cod_circuito = reg.cod_circuito
         and cod_tip_circuito = reg.cod_tip_circuito;
    elsif reg.cod_tip_circuito = 82 then
      update wf_cir_tareas 
         set estado = 'V'
       where cod_circuito = reg.cod_circuito
         and cod_tip_circuito = reg.cod_tip_circuito;
              
      update wf_circuitos 
         set estado = 'V'
       where cod_circuito = reg.cod_circuito;
    end if;    
  end loop;
exception
  when others then
    raise_application_error(-20000, 'Error en PRA_ACT_MONTO_MINIMO: ' || sqlerrm);
END;
/

