create or replace procedure it.PRP_ELI_LIM_GLOBAL(P_NRO_LINEA IN NUMBER) is
  v_lugar   varchar2(20);
Begin
   -- Inserta el limite
   PRP_INS_HIS_LIM_GLOBAL(P_NRO_LINEA);
   -- Elimina todos los datos de limite.
  v_lugar:= ' Punto 1 ';
   Delete pr_gru_lin_aplicaciones
    where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 2 ';
   Delete pr_gru_lin_tip_gar_mad
    where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 3 ';
   Delete pr_gru_lin_tip_garantias
    where nro_linea = p_nro_linea;

  --Elimina el Limite Global--
   Delete pr_gru_lineas
    where nro_linea = p_nro_linea;
EXCEPTION
  when others then
    if sqlcode <= -20000 then
       raise;
    else
       raise_application_error(-20000, 'Error al eliminar el límite: '||p_nro_linea||' '||v_lugar||sqlerrm);
    end if;
end PRP_ELI_LIM_GLOBAL;
/

