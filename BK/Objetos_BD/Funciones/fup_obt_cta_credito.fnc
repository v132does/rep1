CREATE OR REPLACE Function IT.FUP_OBT_CTA_CREDITO(P_NROCTA Varchar2)
		 Return Varchar2 Is
		 V_CTA PR_CTA_PRESTAMOS.NRO_CUENTA%Type;
Begin
		 --MODULO 3
		 Begin
					Select B.NRO_CUENTA
						Into V_CTA
						From PR_MOVIMIENTOS_HIS A,
								 AH_MOVIMIENTOS_HIS B
					 Where A.FECHA = B.FECHA
						 And A.HORA = B.HORA
						 And A.COD_USUARIO = B.COD_USUARIO
						 And A.COD_TRA_PADRE = 358
						 And B.Cod_Transaccion = 602
             AND B.Cod_Modalidad = 31
             AND B.Nro_Cuenta IS NOT NULL
						 And A.NRO_CUENTA = P_NROCTA
             AND ROWNUM = 1;
		 Exception
					When Others Then
							 V_CTA := Null;
		 End;
	
		 --MODULO 4
		 If V_CTA Is Null Then
					Begin
							 Select B.NRO_CUENTA
								 Into V_CTA
								 From PR_MOVIMIENTOS_HIS A,
											CC_MOVIMIENTOS_HIS B
								Where A.FECHA = B.FECHA
									And A.HORA = B.HORA
									And A.COD_USUARIO = B.COD_USUARIO
									And A.COD_TRA_PADRE = B.COD_TRA_PADRE
									And A.COD_TRA_PADRE = 358
									And B.Cod_Transaccion = 602
                  AND B.Cod_Modalidad = 41
                  AND B.Nro_Cuenta IS NOT NULL
									And A.NRO_CUENTA = P_NROCTA
                  AND ROWNUM = 1;
					Exception
							 When Others Then
										V_CTA := Null;
					End;
		 End If;
     Return V_CTA;
Exception
		 When Others Then
					Return V_CTA;
End;
/

