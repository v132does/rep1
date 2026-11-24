CREATE OR REPLACE PROCEDURE IT.PRS_INS_SB_RESOLUCIO
 IS

/* Insertar los datos para la tabla sb_resolucion_tmp. */
PROCEDURE LP_INS_SB_ORD_3
 (P_TIPO IN SB_CLIENTES.TIPO%TYPE
 ,P_CATEGORIA IN SB_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_TIP_DESTINO IN SB_CLA_OPERACIONES.TIP_DESTINO%TYPE
 ,P_COD_GRU_ECONOMICO IN SB_CLIENTES.COD_GRU_ECONOMICO%TYPE
 ,P_ORDEN IN NUMBER
 ,P_DESCRIPCION IN VARCHAR2
 );
/* Obtener el total de la deuda de sb_cla_operaciones. */
FUNCTION LF_OBT_TOT_DEUDA
 (P_TIPO IN SB_CLIENTES.TIPO%TYPE
 ,P_CATEGORIA IN SB_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_TIP_DESTINO IN SB_CLA_OPERACIONES.TIP_DESTINO%TYPE
 ,P_COD_GRU_ECONOMICO IN SB_CLIENTES.COD_GRU_ECONOMICO%TYPE
 ,P_GRU_ENTIDAD IN SB_CLIENTES.COD_GRU_ECONOMICO%TYPE
 )
 RETURN NUMBER;

/* Insertar los datos para la tabla sb_resolucion_tmp. */
PROCEDURE LP_INS_SB_ORD_3
 (P_TIPO IN SB_CLIENTES.TIPO%TYPE
 ,P_CATEGORIA IN SB_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_TIP_DESTINO IN SB_CLA_OPERACIONES.TIP_DESTINO%TYPE
 ,P_COD_GRU_ECONOMICO IN SB_CLIENTES.COD_GRU_ECONOMICO%TYPE
 ,P_ORDEN IN NUMBER
 ,P_DESCRIPCION IN VARCHAR2
 )
 IS
v1 number(18,2);
v2 number(18,2);
v3 number(18,2);
v4 number(18,2);
v5 number(18,2);
v6 number(18,2);
v7 number(18,2);
V_GRU_ENTIDAD NUMBER;
BEGIN
V_GRU_ENTIDAD := fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD',NULL,NULL,NULL,NULL);
    -- Insertar las lineas 4,5 y 6 Grandes Deudores Comerciales, para todos los grupos

    v1:=  lf_obt_tot_deuda('R',1,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD)+
		       lf_obt_tot_deuda('M',1,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD);

    v2:=  lf_obt_tot_deuda('R',2,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD)+
		       lf_obt_tot_deuda('M',2,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD);

    v3:=  lf_obt_tot_deuda('R',3,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD)+
		       lf_obt_tot_deuda('M',3,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD);

    v4:= lf_obt_tot_deuda('R',4,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD)+
		       lf_obt_tot_deuda('M',4,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD);

	  v5:= lf_obt_tot_deuda('R',5,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD)+
		       lf_obt_tot_deuda('M',5,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD);

    v6:= lf_obt_tot_deuda('R',6,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD)+
		       lf_obt_tot_deuda('M',6,null,P_COD_GRU_ECONOMICO,V_GRU_ENTIDAD);

    v7:= nvl(v1,0)+nvl(v2,0)+nvl(v3,0)+nvl(v4,0)+nvl(v5,0)+nvl(v6,0);



    INSERT INTO SB_RESOLUCION_TMP
			(ORDEN, DESCRIPCION, UNO, DOS, TRES, CUATRO, CINCO, SEIS , TOTAL)
		VALUES(P_ORDEN,
			   P_DESCRIPCION, 
		       v1,v2,v3,v4,v5,v6,v7);
     commit;




END;
/* Obtener el total de la deuda de sb_cla_operaciones. */
FUNCTION LF_OBT_TOT_DEUDA
 (P_TIPO IN SB_CLIENTES.TIPO%TYPE
 ,P_CATEGORIA IN SB_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_TIP_DESTINO IN SB_CLA_OPERACIONES.TIP_DESTINO%TYPE
 ,P_COD_GRU_ECONOMICO IN SB_CLIENTES.COD_GRU_ECONOMICO%TYPE
  ,P_GRU_ENTIDAD IN SB_CLIENTES.COD_GRU_ECONOMICO%TYPE
 )
 RETURN NUMBER
 IS

V_VALOR SB_CLIENTES.TOT_DEU_REAL%TYPE;
V_GRU_ENTIDAD NUMBER;
BEGIN
    -- V_GRU_ENTIDAD := fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD',NULL,NULL,NULL,NULL);
      if P_COD_GRU_ECONOMICO is not null
        and P_COD_GRU_ECONOMICO = P_GRU_ENTIDAD then  -- Obtener total deuda para el tipo,
                                              -- la categoria y el grupo economico
        select sum(nvl(sb_cla_operaciones.tot_deu_real, 0))
          into v_valor
          from sb_clientes, sb_cla_operaciones
         where sb_clientes.cod_persona = sb_cla_operaciones.cod_persona
           and sb_clientes.tipo = P_TIPO
           and trunc(nvl(sb_clientes.cat_subjetiva, sb_clientes.cat_automatica)) = P_CATEGORIA
           and nvl(sb_clientes.cod_gru_economico,-1) = P_GRU_ENTIDAD;

      elsif P_COD_GRU_ECONOMICO is not null
            and P_COD_GRU_ECONOMICO = 999 then -- Otros Grupos no vinculados otra entidad
         select sum(nvl(sb_cla_operaciones.tot_deu_real, 0))
          into v_valor
          from sb_clientes, sb_cla_operaciones
         where sb_clientes.cod_persona = sb_cla_operaciones.cod_persona
           and sb_clientes.tipo = P_TIPO
           and trunc(nvl(sb_clientes.cat_subjetiva, sb_clientes.cat_automatica)) = P_CATEGORIA
           and nvl(sb_clientes.cod_gru_economico,-1) <> P_GRU_ENTIDAD;
      elsif P_COD_GRU_ECONOMICO is not null
            and P_COD_GRU_ECONOMICO = -1 Then  -- Obtener total deuda para el tipo,
        select sum(nvl(sb_cla_operaciones.tot_deu_real, 0))
          into v_valor
          from sb_clientes, sb_cla_operaciones
         where sb_clientes.cod_persona = sb_cla_operaciones.cod_persona
           and sb_clientes.tipo = P_TIPO
           and trunc(nvl(sb_clientes.cat_subjetiva, sb_clientes.cat_automatica)) = P_CATEGORIA
           and nvl(sb_clientes.cod_gru_economico,-1) = -1;
      end if;

      return NVL(v_valor,0);



  END;
BEGIN

 --INSERTAR ORDEN 3
 /*LP_INS_SB_ORD_3(NULL,NULL,NULL,
                 fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD',NULL,NULL,NULL,NULL),
                 3,'Vinculados a la Entidad de Crédito (*)');
 LP_INS_SB_ORD_3(NULL,NULL,NULL,
                 999,
                 4,'Vinculados a Otros Grupos (*)');*/
 LP_INS_SB_ORD_3(NULL,NULL,NULL,
                 -1,
                 5,'Deudores no vinculados');



END;
/

