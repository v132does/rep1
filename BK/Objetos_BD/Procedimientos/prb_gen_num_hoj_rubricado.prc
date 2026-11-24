create or replace procedure it.prb_gen_num_hoj_rubricado(p_num_desde in number, p_num_hasta number) is
v_indice number(12);
v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(2);
begin
  --Verificaciones Iniciales--
  if ((p_num_desde < 0) or (p_num_hasta < 0)) then
     RAISE_APPLICATION_ERROR(-20000,'No se puede tener parametros Negativos. '||SQLERRM);
  end if;
  if p_num_desde > p_num_hasta then
     RAISE_APPLICATION_ERROR(-20000,'Parametro Desde no puede ser mayor a Hasta. '||SQLERRM);
  end if;

  --Eliminar Registros anteriores--
  delete from cb_num_hoj_rubricado_tmp;

  --Insertar Nuevos Registros--
  for v_indice in p_num_desde..p_num_hasta loop
      insert into cb_num_hoj_rubricado_tmp
      (fecha, cod_usuario, nro_hoja)
      values
      (v_fecha, user, v_indice);
  end loop;
end prb_gen_num_hoj_rubricado;
/

