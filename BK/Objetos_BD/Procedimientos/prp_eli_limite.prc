CREATE OR REPLACE PROCEDURE IT.PRP_ELI_LIMITE (P_NRO_LINEA IN NUMBER) is
  Cursor c1 is
      Select nro_linea, nro_sec_padre, cod_persona, nro_cuenta
        from pv_operaciones
       where nro_linea = p_nro_linea;
  v_lugar   varchar2(20);
Begin
   -- Inserta el limite
   PRP_INS_HIS_LIMITE(P_NRO_LINEA);
   --
   For r1 in c1 Loop
      -- Desaplica antes de eliminar...
      prp_des_lim_credito(p_nro_linea, r1.nro_cuenta, r1.nro_sec_padre);
      If r1.nro_sec_padre > 0 then
         PRC_ELI_LIN_SOBREGIRO(r1.nro_sec_padre, r1.nro_linea);
      End if;
   End Loop;
   -- Elimina todos los datos de limite.
  v_lugar:= ' Punto 1 ';
   Delete pr_lin_aplicaciones
    where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 2 ';
   Delete pr_lin_tip_gar_mad
    where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 3 ';
   Delete pr_lin_tip_garantias
    where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 4 ';
   update pr_cta_prestamos set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 5 ';
   update CX_cta_importaciones set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 6 ';
   update CX_cta_exportaciones set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 7 ';
   update ta_cta_tarjetas set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 8 ';
   update CX_fianzas set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 9 ';
   update pr_solicitudes set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 10 ';
   update ta_solicitudes set nro_linea = null where nro_linea = p_nro_linea;
  v_lugar:= ' Punto 11 ';
   DELETE pr_lin_pre_aprobados
    WHERE nro_lin_pre_aprobado = p_nro_linea
      AND estado = 'V';
   UPDATE pr_lin_pre_aprobados
      SET estado = 'C'   
    WHERE nro_lin_pre_aprobado = p_nro_linea
      AND estado <> 'V';
      
   Delete pr_lineas
    where nro_linea = p_nro_linea;
EXCEPTION
  when others then
    if sqlcode <= -20000 then
       raise;
    else
       raise_application_error(-20000, 'Error al eliminar el límite: '||p_nro_linea||' '||v_lugar||sqlerrm);
    end if;
end PRP_ELI_LIMITE;
/

