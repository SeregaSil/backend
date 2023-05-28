from typing import Annotated, List
from fastapi import APIRouter, Depends, HTTPException, Query
from src.database import get_connector

from src.core.auth import get_current_connector
from psycopg2._psycopg import connection
from src.schemas.client import ClientInfo, ClientCreate, ClientUpdate

router = APIRouter(tags=['Clients'], prefix='/clients')

@router.get('/info', response_model=ClientInfo)
def get_client_by_telephone(
    telephone: Annotated[
        str, Query(min_length=18, max_length=18,
                          regex='(\+7) (\(9(\d{2})\)) (\d{3})-(\d{2})-(\d{2})')
    ], conn: connection = Depends(get_current_connector)
):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT client_id, full_name, telephone, email, amount_visits, bonus, estate
                            FROM clients
                            WHERE telephone = %s''', (telephone,))
            client: ClientInfo = cur.fetchone()
            if not client:
                raise HTTPException(status_code=404, detail='Not Found')
            return client

@router.get('/{client_id}', response_model=ClientInfo)
def get_client(client_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT client_id, full_name, telephone, email, amount_visits, bonus, estate
                            FROM clients
                            WHERE client_id = %s''', (client_id,))
            client: ClientInfo = cur.fetchone()
            if not client:
                raise HTTPException(status_code=404, detail='Not Found')
            return client
            
@router.post('')
def create_client(client: ClientCreate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''INSERT INTO clients(full_name, telephone, email) VALUES(%s, %s, %s)''',
                        (client.full_name, client.telephone, client.email))


@router.delete('/{client_id}')
def delete_client(client_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''DELETE FROM clients WHERE client_id = %s''', (client_id, ))

@router.patch('/{client_id}')
def update_client(client_id: int, client_info: ClientInfo, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''UPDATE clients
                            SET full_name = %s,
                                telephone = %s,
                                email = %s
                            WHERE client_id = %s;''', 
                            (client_info.full_name, client_info.telephone, client_info.email, client_id,))

@router.get('', response_model=List[ClientInfo])
def get_all_clients(conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT client_id, full_name, telephone, email, amount_visits, bonus, estate
                            FROM clients''')
            clients: List[ClientInfo] = cur.fetchall()
            return clients