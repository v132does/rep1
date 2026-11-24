CREATE OR REPLACE PROCEDURE IT.PRH_ELI_INGRESOS
 (P_COD_EPR_DESDE IN RH_EMPLEADOS.COD_PER_EMPRESA%TYPE
 ,P_COD_EPR_HASTA IN RH_EMPLEADOS.COD_PER_EMPRESA%TYPE
 ,P_COD_EMP_DESDE IN RH_EMPLEADOS.COD_PERSONA%TYPE
 ,P_COD_EMP_HASTA IN RH_EMPLEADOS.COD_PERSONA%TYPE
 ,P_FEC_PROCESO IN DATE
 )
 IS
BEGIN
   delete rh_ingresos d
   where  d.cod_persona >= p_cod_emp_desde
   and    d.cod_persona <= p_cod_emp_hasta
   and    d.fecha >= p_fec_proceso
   and    d.ind_procesado = 'N'
   and    d.ind_automatico = 'S'
   and    exists (   select 1
                     from   rh_empleados e
                     where  d.cod_persona = e.cod_persona
                     and    e.fec_egreso is null
                     and    e.cod_per_empresa >= p_cod_epr_desde
                     and    e.cod_per_empresa <= p_cod_epr_hasta );
exception
   when others then
      raise_application_error(-20000,
      'Error al Eliminar Ingreso del Empleado. '||sqlerrm);
END;
/

